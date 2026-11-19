<?php

namespace CodeIt\Mobile\Http\Controllers;

use CodeIt\Mobile\Support\RouteGate;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Webkul\User\Models\User;

class AuthController extends Controller
{
    /** email + password of a CRM user -> long-lived token for this device. */
    public function login(): JsonResponse
    {
        $data = request()->validate([
            'email' => ['required', 'email', 'max:190'],
            'password' => ['required', 'string', 'max:190'],
            'device' => ['nullable', 'string', 'max:120'],
        ]);
        $user = User::where('email', $data['email'])->first();
        if (! $user || ! Hash::check($data['password'], $user->password)) {
            return response()->json(['error' => ['code' => 'bad_login', 'message' => 'الإيميل أو كلمة السر غلط.']], 422);
        }
        if (! (int) $user->status) {
            return response()->json(['error' => ['code' => 'inactive', 'message' => 'الحساب ده متوقف. كلّم مدير النظام.']], 403);
        }
        $token = $user->createToken('codeit-mobile', ['mobile'])->plainTextToken;
        DB::table('personal_access_tokens')->where('token', hash('sha256', explode('|', $token, 2)[1]))
            ->update(['last_used_at' => now()]);
        // keep at most 5 devices per person
        $keep = DB::table('personal_access_tokens')->where('tokenable_type', $user->getMorphClass())->where('tokenable_id', $user->id)
            ->where('name', 'codeit-mobile')->orderByDesc('id')->limit(5)->pluck('id');
        DB::table('personal_access_tokens')->where('tokenable_type', $user->getMorphClass())->where('tokenable_id', $user->id)
            ->where('name', 'codeit-mobile')->whereNotIn('id', $keep)->delete();

        auth()->guard('user')->setUser($user);

        return response()->json(['token' => $token, 'user' => $this->profile($user)]);
    }

    public function logout(): JsonResponse
    {
        $token = request()->attributes->get('ci_token');
        if ($token) {
            if (Schema::hasTable('codeit_mobile_devices')) {
                DB::table('codeit_mobile_devices')->where('token_id', $token->id)->delete();
            }
            $token->delete();
        }

        return response()->json(['ok' => true]);
    }

    public function me(): JsonResponse
    {
        return response()->json(['user' => $this->profile($this->user()), 'min_build' => (int) config('codeit_mobile.min_build', 1)]);
    }

    /** Push token from Firebase for this device. */
    public function device(): JsonResponse
    {
        $data = request()->validate([
            'push_token' => ['required', 'string', 'max:500'],
            'platform' => ['required', 'in:android,ios'],
            'app_version' => ['nullable', 'string', 'max:40'],
        ]);
        $token = request()->attributes->get('ci_token');
        DB::table('codeit_mobile_devices')->where('push_token', $data['push_token'])->delete();
        DB::table('codeit_mobile_devices')->insert([
            'user_id' => $this->user()->id, 'token_id' => $token?->id, 'push_token' => $data['push_token'],
            'platform' => $data['platform'], 'app_version' => $data['app_version'] ?? null,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return response()->json(['ok' => true]);
    }

    protected function profile(User $u): array
    {
        $u->loadMissing('role');
        $all = $u->role?->permission_type === 'all';
        $emp = Schema::hasTable('codeit_employees') ? DB::table('codeit_employees')->where('user_id', $u->id)->first() : null;
        $dep = $emp && $emp->group_id ? DB::table('groups')->where('id', $emp->group_id)->value('name') : null;
        $manages = Schema::hasTable('codeit_hr_departments') && DB::table('codeit_hr_departments')->where('manager_id', $u->id)->exists();

        // which screens this person may open, by the same route permissions as the web
        $screens = [];
        foreach ([
            'dashboard' => 'admin.dashboard.index',
            'leads' => 'admin.leads.index',
            'quotes' => 'admin.quotes.index',
            'activities' => 'admin.activities.index',
            'mail' => 'admin.mail.index',
            'persons' => 'admin.contacts.persons.index',
            'organizations' => 'admin.contacts.organizations.index',
            'products' => 'admin.products.index',
            'projects' => 'admin.codeit.projects.index',
            'team_tasks' => 'admin.codeit.team.index',
            'tickets' => 'admin.codeit.tickets.index',
            'support_packages' => 'admin.codeit.packages.index',
            'invoices' => 'admin.codeit.invoices.index',
            'careers' => 'admin.codeit.careers.index',
            'chat' => 'admin.codeit.chat.index',
            'chat_monitor' => 'admin.codeit.chatmonitor.list',
            'hr_me' => 'admin.codeit.hr.me',
            'hr_employees' => 'admin.codeit.hr.index',
            'hr_attendance' => 'admin.codeit.hr.attendance',
            'hr_leaves' => 'admin.codeit.hr.leaves',
            'hr_payroll' => 'admin.codeit.hr.payroll',
            'settings' => 'admin.settings.index',
            // what they may change (the app hides the edit / add buttons otherwise)
            'task_edit' => 'admin.codeit.team.edit', 'task_create' => 'admin.codeit.team.create', 'project_edit' => 'admin.codeit.projects.edit', 'project_create' => 'admin.codeit.projects.create',
            'invoice_edit' => 'admin.codeit.invoices.edit', 'invoice_create' => 'admin.codeit.invoices.create', 'ticket_create' => 'admin.codeit.tickets.create',
            'lead_create' => 'admin.leads.create', 'person_create' => 'admin.contacts.persons.create', 'organization_create' => 'admin.contacts.organizations.create',
        ] as $key => $route) {
            if (\Illuminate\Support\Facades\Route::has($route) && RouteGate::can($route)) {
                $screens[] = $key;
            }
        }

        $perms = $all ? ['*'] : array_values((array) $u->role?->permissions);

        return [
            'id' => $u->id,
            'name' => $u->name,
            'email' => $u->email,
            'role' => (string) $u->role?->name,
            'avatar' => $u->image ? url($u->image_url) : null,
            'is_admin' => $all,
            'is_manager' => $manages,
            'department' => $dep,
            'employee_code' => $emp->code ?? null,
            'job_title' => Schema::hasTable('codeit_team_members') ? DB::table('codeit_team_members')->where('user_id', $u->id)->value('job_title') : null,
            'permissions' => $perms,
            'screens' => $screens,
        ];
    }
}
