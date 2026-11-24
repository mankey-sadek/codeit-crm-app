<?php

namespace CodeIt\Mobile\Http\Controllers;

use CodeIt\Mobile\Support\RouteGate;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * CRM settings in the app: users, groups, roles and permissions, pipelines and stages, lead sources,
 * lead types, tags. Lists read the tables after the same permission check as the web page; every save
 * and delete runs the web's own action.
 */
class SettingsController extends Controller
{
    /** The simple "name only" settings: table, web route prefix, extra fields. */
    protected const SIMPLE = [
        'groups' => ['table' => 'groups', 'route' => 'admin.settings.groups', 'fields' => ['name', 'description']],
        'sources' => ['table' => 'lead_sources', 'route' => 'admin.settings.sources', 'fields' => ['name']],
        'types' => ['table' => 'lead_types', 'route' => 'admin.settings.types', 'fields' => ['name']],
        'tags' => ['table' => 'tags', 'route' => 'admin.settings.tags', 'fields' => ['name', 'color']],
    ];

    /** Which settings this person may open. */
    public function catalog(): JsonResponse
    {
        $all = [
            'users' => 'admin.settings.users.index', 'roles' => 'admin.settings.roles.index', 'groups' => 'admin.settings.groups.index',
            'pipelines' => 'admin.settings.pipelines.index', 'sources' => 'admin.settings.sources.index',
            'types' => 'admin.settings.types.index', 'tags' => 'admin.settings.tags.index',
            'hr_departments' => 'admin.codeit.hr.departments', 'hr_settings' => 'admin.codeit.hr.settings',
            'email_templates' => 'admin.settings.email_templates.index',
            'workflows' => 'admin.settings.workflows.index', 'webhooks' => 'admin.settings.webhooks.index',
            'web_forms' => 'admin.settings.web_forms.index', 'attributes' => 'admin.settings.attributes.index',
            'warehouses' => 'admin.settings.warehouses.index', 'events' => 'admin.settings.marketing.events.index',
            'campaigns' => 'admin.settings.marketing.campaigns.index', 'imports' => 'admin.settings.data_transfer.imports.index',
            'configuration' => 'admin.configuration.index',
        ];

        return response()->json([
            'data' => collect($all)->filter(fn ($r) => \Illuminate\Support\Facades\Route::has($r) && RouteGate::can($r))->keys()->values(),
            'web' => collect($all)->only(['workflows', 'webhooks', 'web_forms', 'attributes', 'warehouses', 'events', 'campaigns', 'imports', 'configuration'])
                ->filter(fn ($r) => \Illuminate\Support\Facades\Route::has($r))->map(fn ($r) => parse_url(route($r), PHP_URL_PATH)),
        ]);
    }

    /* ------------------------------------------------------------------ simple lists */

    public function simpleIndex(string $kind): JsonResponse
    {
        $c = $this->simple($kind);
        (new RouteGate)->authorizeRoute($c['route'].'.index');
        $rows = DB::table($c['table'])->orderBy('name')->get(array_merge(['id'], $c['fields']));
        if ($kind === 'groups') {
            $counts = DB::table('user_groups')->groupBy('group_id')->select('group_id', DB::raw('COUNT(*) n'))->pluck('n', 'group_id');
            $rows = $rows->map(fn ($r) => (array) $r + ['count' => (int) ($counts[$r->id] ?? 0)]);
        } elseif ($kind === 'sources' || $kind === 'types') {
            $col = $kind === 'sources' ? 'lead_source_id' : 'lead_type_id';
            $counts = DB::table('leads')->groupBy($col)->select($col, DB::raw('COUNT(*) n'))->pluck('n', $col);
            $rows = $rows->map(fn ($r) => (array) $r + ['count' => (int) ($counts[$r->id] ?? 0)]);
        } elseif ($kind === 'tags') {
            $counts = Schema::hasTable('lead_tags') ? DB::table('lead_tags')->groupBy('tag_id')->select('tag_id', DB::raw('COUNT(*) n'))->pluck('n', 'tag_id') : collect();
            $rows = $rows->map(fn ($r) => (array) $r + ['count' => (int) ($counts[$r->id] ?? 0)]);
        }

        return response()->json(['data' => $rows->values()]);
    }

    public function simpleStore(string $kind): JsonResponse
    {
        $c = $this->simple($kind);

        return $this->act($c['route'].'.store', [], $this->simpleInput($kind));
    }

    public function simpleUpdate(string $kind, int $id): JsonResponse
    {
        $c = $this->simple($kind);

        return $this->act($c['route'].'.update', ['id' => $id], $this->simpleInput($kind) + ['id' => $id]);
    }

    public function simpleDestroy(string $kind, int $id): JsonResponse
    {
        $c = $this->simple($kind);

        return $this->act($c['route'].'.delete', ['id' => $id]);
    }

    protected function simple(string $kind): array
    {
        abort_unless(isset(self::SIMPLE[$kind]), 404);

        return self::SIMPLE[$kind];
    }

    protected function simpleInput(string $kind): array
    {
        $in = ['name' => trim((string) request('name'))];
        if ($kind === 'groups') {
            $in['description'] = trim((string) request('description')) ?: $in['name'];
        }
        if ($kind === 'tags') {
            $in['color'] = (string) request('color', '#2BFF88');
        }

        return $in;
    }

    /* ------------------------------------------------------------------ users */

    public function users(): JsonResponse
    {
        (new RouteGate)->authorizeRoute('admin.settings.users.index');
        $groups = DB::table('user_groups')->get()->groupBy('user_id');
        $roles = DB::table('roles')->pluck('name', 'id');
        $q = trim((string) request('q'));

        return response()->json([
            'data' => DB::table('users')
                ->when($q !== '', fn ($w) => $w->where(fn ($x) => $x->where('name', 'like', "%$q%")->orWhere('email', 'like', "%$q%")))
                ->orderByDesc('status')->orderBy('name')->get(['id', 'name', 'email', 'status', 'role_id', 'view_permission', 'created_at'])
                ->map(fn ($u) => [
                    'id' => $u->id, 'name' => $u->name, 'email' => $u->email, 'status' => (bool) $u->status,
                    'role_id' => $u->role_id, 'role' => $roles[$u->role_id] ?? '', 'view_permission' => $u->view_permission,
                    'groups' => collect($groups[$u->id] ?? [])->pluck('group_id')->map(fn ($v) => (int) $v)->values(),
                    'is_me' => (int) $u->id === $this->user()->id,
                ]),
            'roles' => DB::table('roles')->orderBy('name')->get(['id', 'name', 'permission_type']),
            'groups' => DB::table('groups')->orderBy('name')->get(['id', 'name']),
        ]);
    }

    public function storeUser(): JsonResponse
    {
        return $this->act('admin.settings.users.store', [], $this->userInput());
    }

    public function updateUser(int $id): JsonResponse
    {
        return $this->act('admin.settings.users.update', ['id' => $id], $this->userInput() + ['id' => $id]);
    }

    public function destroyUser(int $id): JsonResponse
    {
        return $this->act('admin.settings.users.delete', ['id' => $id]);
    }

    protected function userInput(): array
    {
        $in = [
            'name' => trim((string) request('name')),
            'email' => trim((string) request('email')),
            'role_id' => (int) request('role_id'),
            'status' => request()->boolean('status') ? 1 : 0,
            'view_permission' => (string) request('view_permission', 'global'),
            'groups' => array_values(array_map('intval', (array) request('groups', []))),
        ];
        if (filled(request('password'))) {
            $in['password'] = (string) request('password');
            $in['confirm_password'] = (string) request('password');
        }

        return $in;
    }

    /* ------------------------------------------------------------------ roles */

    public function roles(): JsonResponse
    {
        (new RouteGate)->authorizeRoute('admin.settings.roles.index');
        $counts = DB::table('users')->groupBy('role_id')->select('role_id', DB::raw('COUNT(*) n'))->pluck('n', 'role_id');

        return response()->json(['data' => DB::table('roles')->orderBy('id')->get(['id', 'name', 'description', 'permission_type', 'permissions'])
            ->map(fn ($r) => [
                'id' => $r->id, 'name' => $r->name, 'description' => $r->description, 'permission_type' => $r->permission_type,
                'permissions' => $r->permission_type === 'custom' ? array_values((array) json_decode((string) $r->permissions, true)) : [],
                'users' => (int) ($counts[$r->id] ?? 0),
            ]),
            'acl' => $this->aclTree(),
        ]);
    }

    public function storeRole(): JsonResponse
    {
        return $this->act('admin.settings.roles.store', [], $this->roleInput());
    }

    public function updateRole(int $id): JsonResponse
    {
        return $this->act('admin.settings.roles.update', ['id' => $id], $this->roleInput());
    }

    public function destroyRole(int $id): JsonResponse
    {
        return $this->act('admin.settings.roles.delete', ['id' => $id]);
    }

    protected function roleInput(): array
    {
        $type = request('permission_type') === 'all' ? 'all' : 'custom';
        $in = [
            'name' => trim((string) request('name')),
            'description' => trim((string) request('description')) ?: trim((string) request('name')),
            'permission_type' => $type,
        ];
        if ($type === 'custom') {
            $in['permissions'] = array_values(array_filter((array) request('permissions', []), 'is_string'));
        }

        return $in;
    }

    /** The permission tree as a flat list in order, with depth (for an indented checklist). */
    protected function aclTree(): array
    {
        $out = [];
        $walk = function (Collection $items, int $depth) use (&$walk, &$out) {
            foreach ($items->sortBy('sort') as $i) {
                $i = is_array($i) ? $i : (array) $i;
                $out[] = ['key' => $i['key'], 'name' => trans($i['name']), 'depth' => $depth];
                if (! empty($i['children']) && $i['children'] instanceof Collection) {
                    $walk($i['children'], $depth + 1);
                }
            }
        };
        $walk(acl()->getItems(), 0);

        return $out;
    }

    /* ------------------------------------------------------------------ pipelines */

    public function pipelines(): JsonResponse
    {
        (new RouteGate)->authorizeRoute('admin.settings.pipelines.index');
        $leads = DB::table('leads')->groupBy('lead_pipeline_stage_id')->select('lead_pipeline_stage_id', DB::raw('COUNT(*) n'))->pluck('n', 'lead_pipeline_stage_id');

        return response()->json(['data' => DB::table('lead_pipelines')->orderByDesc('is_default')->orderBy('id')->get()->map(fn ($p) => [
            'id' => $p->id, 'name' => $p->name, 'is_default' => (bool) $p->is_default, 'rotten_days' => (int) $p->rotten_days,
            'stages' => DB::table('lead_pipeline_stages')->where('lead_pipeline_id', $p->id)->orderBy('sort_order')
                ->get(['id', 'code', 'name', 'probability', 'sort_order'])
                ->map(fn ($s) => (array) $s + ['leads' => (int) ($leads[$s->id] ?? 0)]),
        ])]);
    }

    public function storePipeline(): JsonResponse
    {
        return $this->act('admin.settings.pipelines.store', [], $this->pipelineInput());
    }

    public function updatePipeline(int $id): JsonResponse
    {
        return $this->act('admin.settings.pipelines.update', ['id' => $id], $this->pipelineInput() + ['id' => $id]);
    }

    public function destroyPipeline(int $id): JsonResponse
    {
        return $this->act('admin.settings.pipelines.delete', ['id' => $id]);
    }

    /** Stages come as a list; existing ones keep their id as key, new ones get "stage_n" like the web form. */
    protected function pipelineInput(): array
    {
        $stages = [];
        foreach (array_values((array) request('stages', [])) as $n => $s) {
            if (! is_array($s) || trim((string) ($s['name'] ?? '')) === '') {
                continue;
            }
            $name = trim((string) $s['name']);
            $code = trim((string) ($s['code'] ?? '')) ?: \Illuminate\Support\Str::slug($name) ?: 'stage-'.($n + 1);
            $key = ! empty($s['id']) ? (string) (int) $s['id'] : 'stage_'.$n;
            $stages[$key] = ['name' => $name, 'code' => $code, 'probability' => (int) ($s['probability'] ?? 0), 'sort_order' => $n + 1];
        }
        $in = ['name' => trim((string) request('name')), 'rotten_days' => (int) request('rotten_days', 30), 'stages' => $stages];
        if (request()->boolean('is_default')) {
            $in['is_default'] = 1;
        } else {
            request()->request->remove('is_default');
            request()->query->remove('is_default');
        }

        return $in;
    }

    /* ------------------------------------------------------------------ HR: departments, work rules, holidays */

    public function hrDepartments(): JsonResponse
    {
        $d = $this->page('admin.codeit.hr.departments');

        return response()->json([
            'data' => collect($d['deps'] ?? [])->map(fn ($g) => [
                'id' => (int) $g->id, 'name' => $g->name, 'prefix' => $g->prefix, 'manager_id' => $g->manager_id ? (int) $g->manager_id : null,
                'manager' => $g->manager, 'size' => (int) (($d['sizes'] ?? [])[$g->id] ?? 0),
            ])->values(),
            'users' => collect($d['users'] ?? [])->map(fn ($u) => ['id' => (int) $u->id, 'name' => $u->name])->values(),
        ]);
    }

    public function saveHrDepartments(): JsonResponse
    {
        $dep = [];
        foreach ((array) request('departments', []) as $row) {
            if (is_array($row) && ! empty($row['id'])) {
                $dep[(int) $row['id']] = ['prefix' => $row['prefix'] ?? null, 'manager_id' => $row['manager_id'] ?? null];
            }
        }

        return $this->act('admin.codeit.hr.departments.save', [], ['dep' => $dep]);
    }

    public function hrSettings(): JsonResponse
    {
        $d = $this->page('admin.codeit.hr.settings');
        $s = (array) ($d['s'] ?? []);

        return response()->json(['data' => [
            'work_start' => $s['work_start'] ?? '09:00', 'work_end' => $s['work_end'] ?? '17:00',
            'grace_minutes' => (int) ($s['grace_minutes'] ?? 15), 'late_free_minutes' => (int) ($s['late_free_minutes'] ?? 0),
            'weekend' => array_values(array_map('intval', array_filter(explode(',', (string) ($s['weekend'] ?? '5,6')), 'strlen'))),
            'annual_leave_days' => (int) ($s['annual_leave_days'] ?? 21), 'month_days' => (int) ($s['month_days'] ?? 30),
            'currency' => $s['currency'] ?? 'EGP',
            'deduct_absence' => (string) ($s['deduct_absence'] ?? '0') === '1', 'deduct_late' => (string) ($s['deduct_late'] ?? '0') === '1',
            'holidays' => collect($d['holidays'] ?? [])->map(fn ($h) => ['id' => (int) $h->id, 'date' => (string) $h->date, 'name' => $h->name])->values(),
        ]]);
    }

    public function saveHrSettings(): JsonResponse
    {
        $in = request()->only(['work_start', 'work_end', 'grace_minutes', 'weekend', 'annual_leave_days', 'month_days', 'currency', 'late_free_minutes']);
        $in['deduct_absence'] = request()->boolean('deduct_absence') ? 1 : 0;
        $in['deduct_late'] = request()->boolean('deduct_late') ? 1 : 0;

        return $this->act('admin.codeit.hr.settings.save', [], $in + ['weekend' => []]);
    }

    public function storeHoliday(): JsonResponse
    {
        return $this->act('admin.codeit.hr.holidays.store', [], request()->only(['date', 'name']));
    }

    public function deleteHoliday(int $id): JsonResponse
    {
        return $this->act('admin.codeit.hr.holidays.delete', ['id' => $id]);
    }

    /* ------------------------------------------------------------------ e-mail templates */

    public function emailTemplates(): JsonResponse
    {
        (new RouteGate)->authorizeRoute('admin.settings.email_templates.index');

        return response()->json(['data' => DB::table('email_templates')->orderBy('name')->get(['id', 'name', 'subject', 'content'])]);
    }

    public function storeEmailTemplate(): JsonResponse
    {
        return $this->act('admin.settings.email_templates.store', [], request()->only(['name', 'subject', 'content']));
    }

    public function updateEmailTemplate(int $id): JsonResponse
    {
        return $this->act('admin.settings.email_templates.update', ['id' => $id], request()->only(['name', 'subject', 'content']));
    }

    public function destroyEmailTemplate(int $id): JsonResponse
    {
        return $this->act('admin.settings.email_templates.delete', ['id' => $id]);
    }

    /* ------------------------------------------------------------------ the rest: the web page inside the app */

    /**
     * Pages that are big forms on the web (workflows, webhooks, web forms, attributes, warehouses,
     * marketing, imports, configuration) open inside the app as the web page itself. This makes a
     * one-time link (60 seconds, one use) that signs this person in to the web and opens that page.
     */
    public function webLink(): JsonResponse
    {
        $to = (string) request('to', '/admin/settings');
        abort_unless(preg_match('#^/admin(/[A-Za-z0-9_\-/]*)?$#', $to) === 1, 422);
        $code = \Illuminate\Support\Str::random(48);
        \Illuminate\Support\Facades\Cache::put('codeit-mobile-web|'.hash('sha256', $code), ['user' => $this->user()->id, 'to' => $to], 60);

        return response()->json(['url' => url('mobile-web/'.$code)]);
    }
}
