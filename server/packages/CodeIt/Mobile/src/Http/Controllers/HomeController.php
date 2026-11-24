<?php

namespace CodeIt\Mobile\Http\Controllers;

use CodeIt\Mobile\Support\RouteGate;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** The app's home: one call with what this person needs today, only from screens they may open. */
class HomeController extends Controller
{
    public function home(): JsonResponse
    {
        $me = $this->user();
        $tz = 'Africa/Cairo';
        $out = ['now' => now()->toIso8601String()];

        // my tasks (team tasks assigned to me)
        if (Schema::hasTable('codeit_team_tasks') && RouteGate::can('admin.codeit.team.index')) {
            $open = DB::table('codeit_team_tasks')->where('assignee_id', $me->id)->where('status', '!=', 'done');
            $endToday = now($tz)->endOfDay()->utc();
            $out['tasks'] = [
                'open' => (clone $open)->count(),
                'late' => (clone $open)->where('due_at', '<', now())->count(),
                'today' => (clone $open)->where('due_at', '>=', now())->where('due_at', '<=', $endToday)->count(),
                'review' => (clone $open)->where('status', 'review')->count(),
                'next' => (clone $open)->where('status', '!=', 'review')->orderBy('due_at')->limit(5)->get(['id', 'title', 'status', 'priority', 'due_at', 'project_id'])
                    ->map(fn ($t) => ['id' => $t->id, 'title' => $t->title, 'status' => $t->status, 'priority' => $t->priority, 'due_date' => self::iso($t->due_at.' UTC'), 'late' => Carbon::parse($t->due_at, 'UTC')->isPast()])->values(),
            ];
        }

        // attendance today
        if (Schema::hasTable('codeit_employees') && DB::table('codeit_employees')->where('user_id', $me->id)->where('status', 'active')->exists()) {
            $r = DB::table('codeit_hr_attendance')->where('user_id', $me->id)->where('date', now($tz)->toDateString())->first();
            $out['attendance'] = [
                'check_in' => $r && $r->check_in ? self::iso($r->check_in.' UTC') : null,
                'check_out' => $r && $r->check_out ? self::iso($r->check_out.' UTC') : null,
                'late_minutes' => (int) ($r->late_minutes ?? 0),
                'work_start' => \CodeIt\Hr\Support\Hr::setting('work_start', '09:00'),
                'work_end' => \CodeIt\Hr\Support\Hr::setting('work_end', '17:00'),
            ];
        }

        // leave requests waiting for me
        if (class_exists(\CodeIt\Hr\Support\Hr::class) && RouteGate::can('admin.codeit.hr.leaves')) {
            $ids = \CodeIt\Hr\Support\Hr::isAdmin($me) ? null : \CodeIt\Hr\Support\Hr::managedUserIds($me);
            if ($ids === null || $ids) {
                $out['approvals'] = DB::table('codeit_hr_leaves')->where('status', 'pending')->where('user_id', '!=', $me->id)
                    ->when($ids !== null, fn ($q) => $q->whereIn('user_id', $ids))->count();
            }
        }

        // tickets: SLA first
        if (Schema::hasTable('tickets') && RouteGate::can('admin.codeit.tickets.index')) {
            $t = DB::table('tickets')->where('status', '!=', 'resolved');
            $out['tickets'] = [
                'open' => (clone $t)->count(),
                'mine' => (clone $t)->where('user_id', $me->id)->count(),
                'late' => (clone $t)->whereNull('first_response_at')->where('response_due_at', '<', now())->count(),
                'next' => (clone $t)->leftJoin('organizations as o', 'o.id', '=', 'tickets.organization_id')
                    ->orderByRaw('first_response_at IS NOT NULL')->orderByRaw("FIELD(priority,'critical','urgent','normal')")->orderBy('response_due_at')
                    ->limit(5)->get(['tickets.id', 'tickets.number', 'tickets.title', 'tickets.priority', 'tickets.status', 'tickets.response_due_at', 'tickets.first_response_at', 'o.name as client'])
                    ->map(fn ($x) => ['id' => $x->id, 'number' => $x->number, 'subject' => $x->title, 'priority' => $x->priority, 'status' => $x->status, 'client' => $x->client ? ['id' => 0, 'name' => $x->client] : null,
                        'sla_minutes' => $x->first_response_at ? null : (int) round(now()->diffInMinutes(Carbon::parse($x->response_due_at, 'UTC'), false))])->values(),
            ];
        }

        // sales pipeline
        if (RouteGate::can('admin.leads.index')) {
            $users = bouncer()->getAuthorizedUserIds();
            $pipe = DB::table('lead_pipelines')->where('is_default', 1)->value('id');
            $out['pipeline'] = DB::table('lead_pipeline_stages as s')->where('s.lead_pipeline_id', $pipe)
                ->leftJoin('leads as l', fn ($j) => $j->on('l.lead_pipeline_stage_id', '=', 's.id')->when($users, fn ($w) => $w->whereIn('l.user_id', $users)))
                ->groupBy('s.id', 's.name', 's.code', 's.sort_order')->orderBy('s.sort_order')
                ->get(['s.id', 's.name', 's.code', DB::raw('COUNT(l.id) as count'), DB::raw('COALESCE(SUM(l.lead_value),0) as value')])
                ->map(fn ($s) => ['id' => $s->id, 'name' => $s->name, 'code' => $s->code, 'count' => (int) $s->count, 'value' => (float) $s->value])->values();
        }

        // my activities today
        if (RouteGate::can('admin.activities.index')) {
            $out['activities'] = DB::table('activities')->where('user_id', $me->id)->where('is_done', 0)->whereIn('type', ['call', 'meeting', 'lunch', 'task'])
                ->whereBetween('schedule_from', [now($tz)->startOfDay()->utc(), now($tz)->endOfDay()->utc()])->orderBy('schedule_from')->limit(8)
                ->get(['id', 'type', 'title', 'schedule_from', 'schedule_to'])
                ->map(fn ($a) => ['id' => $a->id, 'type' => $a->type, 'title' => $a->title, 'schedule_from' => self::iso($a->schedule_from.' UTC'), 'schedule_to' => self::iso($a->schedule_to.' UTC')])->values();
        }

        // money waiting
        if (Schema::hasTable('invoices') && RouteGate::can('admin.codeit.invoices.index')) {
            $inv = \CodeIt\Billing\Models\Invoice::with(['items', 'payments'])->whereIn('status', ['sent', 'partial'])->get();
            $out['invoices'] = [
                'count' => $inv->count(),
                'due' => round($inv->sum(fn ($i) => $i->remaining()), 2),
                'overdue' => round($inv->filter(fn ($i) => $i->due_date && $i->due_date->isPast())->sum(fn ($i) => $i->remaining()), 2),
                'reported' => $inv->whereNotNull('payment_reported_at')->count(),
            ];
        }

        $out['chat_unread'] = $this->chatUnread($me->id);
        $out['notifications_unread'] = DB::table('notifications')->where('user_id', $me->id)->where('is_read', 0)->count();
        $out['sentence'] = $this->sentence($out);

        return response()->json($out);
    }

    protected function chatUnread(int $me): int
    {
        if (! Schema::hasTable('codeit_chat_members')) {
            return 0;
        }

        return (int) DB::table('codeit_chat_members as m')->join('codeit_chat_messages as x', 'x.conversation_id', '=', 'm.conversation_id')
            ->where('m.user_id', $me)->whereColumn('x.id', '>', 'm.last_read_id')->where(fn ($q) => $q->whereNull('x.user_id')->orWhere('x.user_id', '!=', $me))
            ->whereNull('x.deleted_at')->where('x.kind', '!=', 'system')->count();
    }

    /** One plain line for the top of the home screen. */
    protected function sentence(array $o): string
    {
        $bits = [];
        if (! empty($o['tasks']['late'])) {
            $bits[] = $o['tasks']['late'].' '.($o['tasks']['late'] === 1 ? 'مهمة متأخرة' : 'مهام متأخرة');
        }
        if (! empty($o['tasks']['today'])) {
            $bits[] = $o['tasks']['today'].' '.($o['tasks']['today'] === 1 ? 'مهمة تسليمها النهارده' : 'مهام تسليمها النهارده');
        }
        if (! empty($o['tickets']['late'])) {
            $bits[] = $o['tickets']['late'].' '.($o['tickets']['late'] === 1 ? 'تذكرة عدّت وقت الرد' : 'تذاكر عدّت وقت الرد');
        }
        if (! empty($o['approvals'])) {
            $bits[] = $o['approvals'].' '.($o['approvals'] === 1 ? 'طلب إجازة مستني قرارك' : 'طلبات إجازة مستنية قرارك');
        }
        if (! $bits) {
            return 'مفيش حاجة متأخرة النهارده. يوم هادي.';
        }

        return 'عندك '.implode('، و', $bits).'.';
    }

    /* ---------- notifications (the CRM bell) ---------- */

    public function notifications(): JsonResponse
    {
        $p = DB::table('notifications')->where('user_id', $this->user()->id)->orderByDesc('id')->paginate(30);

        return response()->json(self::paged($p, fn ($n) => [
            'id' => $n->id, 'title' => $n->title, 'body' => (string) $n->description, 'kind' => $n->entity_type,
            'entity_id' => $n->entity_id, 'link' => $n->route, 'is_read' => (bool) $n->is_read, 'created_at' => self::iso($n->created_at),
        ]) + ['unread' => DB::table('notifications')->where('user_id', $this->user()->id)->where('is_read', 0)->count()]);
    }

    public function readNotification(int $id): JsonResponse
    {
        DB::table('notifications')->where('user_id', $this->user()->id)->where('id', $id)->update(['is_read' => 1, 'updated_at' => now()]);

        return response()->json(['ok' => true]);
    }

    public function readAllNotifications(): JsonResponse
    {
        DB::table('notifications')->where('user_id', $this->user()->id)->where('is_read', 0)->update(['is_read' => 1, 'updated_at' => now()]);

        return response()->json(['ok' => true]);
    }

    /* ---------- search across what this person can see ---------- */

    public function search(): JsonResponse
    {
        $q = trim((string) request('q'));
        abort_if(mb_strlen($q) < 2, 422);
        $like = '%'.str_replace(['%', '_'], ['\%', '\_'], $q).'%';
        $out = [];
        $users = null;
        if (RouteGate::can('admin.leads.index')) {
            $users = bouncer()->getAuthorizedUserIds();
            $out['leads'] = DB::table('leads')->where('title', 'like', $like)->when($users, fn ($w) => $w->whereIn('user_id', $users))->limit(5)->get(['id', 'title as name']);
        }
        if (RouteGate::can('admin.contacts.persons.index')) {
            $out['persons'] = DB::table('persons')->where('name', 'like', $like)->when($users, fn ($w) => $w->whereIn('user_id', $users))->limit(5)->get(['id', 'name']);
            $out['organizations'] = DB::table('organizations')->where('name', 'like', $like)->limit(5)->get(['id', 'name']);
        }
        if (Schema::hasTable('projects') && RouteGate::can('admin.codeit.projects.index')) {
            $out['projects'] = DB::table('projects')->where(fn ($w) => $w->where('name', 'like', $like)->orWhere('code', 'like', $like))->limit(5)->get(['id', 'name', 'code']);
        }
        if (Schema::hasTable('tickets') && RouteGate::can('admin.codeit.tickets.index')) {
            $out['tickets'] = DB::table('tickets')->where(fn ($w) => $w->where('title', 'like', $like)->orWhere('number', 'like', $like))->limit(5)->get(['id', 'title as name', 'number']);
        }
        if (Schema::hasTable('codeit_team_tasks') && RouteGate::can('admin.codeit.team.index')) {
            $manager = bouncer()->hasPermission('codeit-team-tasks.manage');
            $out['tasks'] = DB::table('codeit_team_tasks')->where('title', 'like', $like)->when(! $manager, fn ($w) => $w->where('assignee_id', $this->user()->id))->limit(5)->get(['id', 'title as name']);
        }
        if (Schema::hasTable('codeit_employees') && RouteGate::can('admin.codeit.hr.index')) {
            $vis = \CodeIt\Hr\Support\Hr::visibleUserIds();
            $out['employees'] = DB::table('codeit_employees as e')->join('users as u', 'u.id', '=', 'e.user_id')
                ->where(fn ($w) => $w->where('u.name', 'like', $like)->orWhere('e.code', 'like', $like))
                ->when($vis !== null, fn ($w) => $w->whereIn('e.user_id', $vis ?: [0]))->limit(5)->get(['e.user_id as id', 'u.name', 'e.code']);
        }

        return response()->json(['data' => $out]);
    }
}
