<?php

namespace CodeIt\Mobile\Http\Controllers;

use CodeIt\Hr\Models\Leave;
use CodeIt\Hr\Support\Hr;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

/** Employees module: my file + clock in/out, leave, team, attendance sheet, payroll and payslips. */
class HrController extends Controller
{
    public function me(): JsonResponse
    {
        // admins don't get a file made for them automatically (same as the web); the app offers a button
        if (! \CodeIt\Hr\Models\Employee::find($this->user()->id) && Hr::isAdmin()) {
            return response()->json(['no_file' => true]);
        }
        $d = $this->page('admin.codeit.hr.me', [], array_filter(['month' => request('month')]));

        return response()->json($this->fileJson($d));
    }

    /** An admin makes their own employee file from the app (to clock in and see their attendance). */
    public function createMyFile(): JsonResponse
    {
        (new \CodeIt\Mobile\Support\RouteGate)->authorizeRoute('admin.codeit.hr.me');
        \CodeIt\Hr\Models\Employee::firstOrCreate(['user_id' => $this->user()->id], ['status' => 'active']);

        return response()->json(['ok' => true, 'message' => 'اتعمل ملفك.']);
    }

    public function employee(int $id): JsonResponse
    {
        $d = $this->page('admin.codeit.hr.view', ['id' => $id], array_filter(['month' => request('month')]));

        return response()->json($this->fileJson($d));
    }

    public function punch(): JsonResponse
    {
        return $this->act('admin.codeit.hr.punch', [], [], fn () => $this->today($this->user()->id));
    }

    public function employees(): JsonResponse
    {
        $d = $this->page('admin.codeit.hr.index', [], array_filter(['status' => request('status'), 'group' => request('group'), 'q' => request('q')]));
        $out = collect($d['byDept'] ?? [])->map(fn ($g) => [
            'id' => $g->id, 'name' => $g->name, 'prefix' => $g->prefix, 'manager' => $g->manager,
            'people' => collect($g->people ?? [])->map(fn ($e) => $this->empJson($e))->values(),
        ]);
        if (collect($d['noDept'] ?? [])->isNotEmpty()) {
            $out->push(['id' => 0, 'name' => 'من غير قسم', 'prefix' => null, 'manager' => null, 'people' => collect($d['noDept'])->map(fn ($e) => $this->empJson($e))->values()]);
        }

        return response()->json(['departments' => $out->values(), 'stats' => $d['stats'] ?? [], 'counts' => $d['counts'] ?? [], 'workday' => (bool) ($d['workday'] ?? true)]);
    }

    public function attendance(): JsonResponse
    {
        $d = $this->page('admin.codeit.hr.attendance', [], array_filter(['month' => request('month'), 'group' => request('group')]));

        return response()->json([
            'month' => $d['month'] ?? null,
            'days' => $d['days'] ?? [],
            'rows' => collect($d['rows'] ?? [])->map(fn ($r) => [
                'employee' => $this->empJson($r['emp']),
                'days' => collect($r['days'] ?? [])->map(fn ($x) => $this->dayJson($x))->values(),
                'summary' => collect($r)->except(['emp', 'days'])->all(),
            ])->values(),
            'departments' => collect($d['deps'] ?? [])->map(fn ($g) => ['id' => $g->id, 'name' => $g->name])->values(),
        ]);
    }

    public function saveAttendance(): JsonResponse
    {
        return $this->act('admin.codeit.hr.attendance.save', [], request()->only(['user_id', 'date', 'status', 'check_in', 'check_out', 'note']));
    }

    public function leaves(): JsonResponse
    {
        $d = $this->page('admin.codeit.hr.leaves');
        $map = fn ($c) => collect($c ?? [])->map(fn ($l) => $this->leaveJson($l))->values();

        return response()->json([
            'mine' => $map($d['mine'] ?? []),
            'inbox' => $map($d['inbox'] ?? []),
            'history' => $map($d['history'] ?? []),
            'balance' => $d['balance'] ?? null,
            'deciding' => (bool) ($d['deciding'] ?? false),
            'has_file' => (bool) ($d['hasFile'] ?? false),
            'types' => Hr::LEAVE_TYPES,
        ]);
    }

    public function storeLeave(): JsonResponse
    {
        return $this->act('admin.codeit.hr.leaves.store', [], request()->only(['type', 'start_date', 'end_date', 'reason', 'user_id']));
    }

    public function decideLeave(int $id): JsonResponse
    {
        return $this->act('admin.codeit.hr.leaves.decide', ['id' => $id], request()->only(['decision', 'note']));
    }

    public function cancelLeave(int $id): JsonResponse
    {
        return $this->act('admin.codeit.hr.leaves.cancel', ['id' => $id]);
    }

    public function payroll(): JsonResponse
    {
        $d = $this->page('admin.codeit.hr.payroll', [], array_filter(['month' => request('month')]));

        return response()->json([
            'month' => $d['month'] ?? null, 'month_label' => isset($d['month']) ? Hr::monthLabel($d['month']) : null,
            'prev' => $d['prev'] ?? null, 'next' => $d['next'] ?? null,
            'totals' => $d['tot'] ?? [],
            'rows' => collect($d['rows'] ?? [])->map(fn ($s) => $this->slipJson($s) + ['department' => is_object($s->dept ?? null) ? $s->dept->name : ($s->dept ?? null), 'code' => $s->emp->code ?? null])->values(),
            'no_salary' => collect($d['noSalary'] ?? [])->map(fn ($e) => $this->empJson($e))->values(),
        ]);
    }

    public function payrollAction(string $action): JsonResponse
    {
        abort_unless(in_array($action, ['refresh', 'approve', 'paid'], true), 404);

        return $this->act('admin.codeit.hr.payroll.'.$action, [], request()->only(['month', 'ids']));
    }

    public function payslip(int $id): JsonResponse
    {
        $d = $this->page('admin.codeit.hr.slip', ['id' => $id]);
        $s = $d['s'] ?? null;
        abort_unless($s, 404);

        return response()->json(['data' => $this->slipJson($s, true)]);
    }

    /* ---------- shapes ---------- */

    protected function fileJson(array $d): array
    {
        $emp = $d['emp'] ?? null;
        abort_unless($emp, 404);
        $cal = $d['cal'] ?? [];
        $isSelf = (bool) ($d['self'] ?? false);

        return [
            'employee' => $this->empJson($emp, true, $isSelf || ! empty($d['payroll'])),
            'self' => $isSelf,
            'department' => isset($d['dept']) && $d['dept'] ? ['id' => $d['dept']->id, 'name' => $d['dept']->name, 'manager' => $d['dept']->manager] : null,
            'job_title' => $d['title'] ?? null,
            'month' => $d['month'] ?? null,
            'month_label' => isset($d['month']) ? Hr::monthLabel($d['month']) : null,
            'calendar' => collect($cal['days'] ?? [])->map(fn ($x) => $this->dayJson($x))->values(),
            'summary' => collect($cal)->except(['days'])->all(),
            'today' => $this->today($emp->user_id),
            'balance' => $d['balance'] ?? null,
            'leaves' => collect($d['leaves'] ?? [])->map(fn ($l) => $this->leaveJson($l))->values(),
            'tasks' => collect($d['tasks'] ?? [])->map(fn ($t) => ['id' => $t->id, 'title' => $t->title, 'status' => $t->status, 'due_at' => self::iso($t->due_at)])->values(),
            'payslips' => collect($d['slips'] ?? [])->map(fn ($s) => $this->slipJson($s))->values(),
            'advances' => collect($d['advances'] ?? [])->map(fn ($a) => ['id' => $a->id, 'amount' => (float) $a->amount, 'months' => $a->months ?? null, 'start_month' => $a->start_month ?? null, 'remaining' => class_exists(\CodeIt\Hr\Support\Payroll::class) ? \CodeIt\Hr\Support\Payroll::remaining($a) : null])->values(),
            'files' => collect($d['files'] ?? [])->map(fn ($f) => ['id' => $f->id, 'kind' => $f->kind, 'name' => $f->name ?? $f->original_name ?? 'ملف', 'size' => (int) ($f->size ?? 0)])->values(),
            'can_decide' => (bool) ($d['canDecide'] ?? false),
            'work_start' => Hr::setting('work_start', '09:00'),
            'work_end' => Hr::setting('work_end', '17:00'),
        ];
    }

    protected function today(int $userId): array
    {
        $r = DB::table('codeit_hr_attendance')->where('user_id', $userId)->where('date', Hr::now()->toDateString())->first();

        return [
            'date' => Hr::now()->toDateString(),
            'check_in' => $r && $r->check_in ? self::iso($r->check_in.' UTC') : null,
            'check_out' => $r && $r->check_out ? self::iso($r->check_out.' UTC') : null,
            'late_minutes' => (int) ($r->late_minutes ?? 0),
            'status' => $r->status ?? null,
        ];
    }

    protected function dayJson(array $x): array
    {
        $fmt = fn ($v) => $v instanceof \DateTimeInterface ? \Carbon\Carbon::instance($v)->setTimezone(Hr::TZ)->format('H:i') : ($v ? (string) $v : null);

        return [
            'date' => $x['date'] ?? null, 'dow' => $x['dow'] ?? null, 'status' => $x['status'] ?? null,
            'in' => $fmt($x['in'] ?? null), 'out' => $fmt($x['out'] ?? null), 'late' => (int) ($x['late'] ?? 0),
            'note' => $x['note'] ?? null,
            'holiday' => is_object($x['holiday'] ?? null) ? ($x['holiday']->name ?? 'عطلة') : ($x['holiday'] ?? null),
            'leave' => is_object($x['leave'] ?? null) ? ($x['leave']->type ?? 'leave') : ($x['leave'] ?? null),
        ];
    }

    protected function empJson($e, bool $full = false, bool $money = false): array
    {
        $u = $e->user;
        $out = [
            'id' => (int) $e->user_id, 'code' => $e->code, 'name' => $u?->name ?? '', 'email' => $u?->email,
            'phone' => $e->phone, 'status' => $e->status, 'group_id' => $e->group_id,
            'hire_date' => optional($e->hire_date)->toDateString(),
            'contract' => $e->contract_type, 'contract_label' => \CodeIt\Hr\Models\Employee::CONTRACTS[$e->contract_type] ?? $e->contract_type,
            'job_title' => $e->getAttribute('title') ?? $e->jobTitle(),
            'today' => $e->getAttribute('today'),
            'today_in' => $e->getAttribute('today_in'),
            'tasks_open' => (int) $e->getAttribute('open'),
            'tasks_late' => (int) $e->getAttribute('late'),
        ];
        if ($full) {
            $out += [
                'birth_date' => optional($e->birth_date)->toDateString(), 'address' => $e->address,
                'national_id' => $e->national_id, 'emergency_name' => $e->emergency_name, 'emergency_phone' => $e->emergency_phone,
                'annual_leave_days' => (int) $e->annual_leave_days, 'left_at' => optional($e->left_at)->toDateString(),
            ];
            if ($money) {
                $out += ['base_salary' => (float) $e->base_salary, 'allowances' => (float) $e->allowances, 'bank_account' => $e->bank_account];
            }
        }

        return $out;
    }

    protected function leaveJson(Leave $l): array
    {
        return [
            'id' => $l->id, 'type' => $l->type, 'type_label' => Hr::LEAVE_TYPES[$l->type] ?? $l->type,
            'from' => optional($l->start_date)->toDateString(), 'to' => optional($l->end_date)->toDateString(),
            'days' => (float) $l->days, 'status' => $l->status, 'status_label' => Hr::LEAVE_STATUS[$l->status] ?? $l->status,
            'reason' => (string) $l->reason, 'manager_note' => $l->decision_note,
            'employee' => $l->relationLoaded('user') && $l->user ? self::ref($l->user) : null,
            'created_at' => self::iso($l->created_at),
        ];
    }

    protected function slipJson($s, bool $full = false): array
    {
        $out = [
            'id' => $s->id, 'month' => $s->month, 'month_label' => Hr::monthLabel($s->month),
            'base' => (float) $s->base, 'additions' => (float) $s->additions, 'deductions' => (float) $s->deductions, 'net' => (float) $s->net,
            'status' => $s->status, 'employee' => $s->relationLoaded('user') && $s->user ? self::ref($s->user) : null,
            'approved_at' => self::iso($s->approved_at), 'paid_at' => self::iso($s->paid_at),
        ];
        if ($full) {
            $out['lines'] = collect($s->lines ?? [])->values();
            $out['attendance'] = $s->attendance;
        }

        return $out;
    }
}
