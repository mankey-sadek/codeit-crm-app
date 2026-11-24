<?php

namespace CodeIt\Mobile\Http\Controllers;

use CodeIt\Billing\Models\Invoice;
use CodeIt\Project\Models\Project;
use CodeIt\Support\Models\Ticket;
use CodeIt\Team\Models\Task as TeamTask;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Projects, team tasks, support tickets and invoices, through the code it modules' own actions. */
class WorkController extends Controller
{
    /* ---------- projects ---------- */

    public function projects(): JsonResponse
    {
        $filters = request('stage') ? ['stage' => [(string) request('stage')]] : [];
        $g = $this->grid('admin.codeit.projects.index', [], $filters, ['column' => 'id', 'order' => 'desc']);
        $rows = self::ordered(Project::class, $g['ids'], ['organization', 'manager', 'members', 'tasks']);

        return response()->json(['data' => $rows->map(fn ($p) => $this->projectJson($p))->values(), 'meta' => $g['meta']]);
    }

    public function project(int $id): JsonResponse
    {
        $p = $this->page('admin.codeit.projects.view', ['id' => $id])['project'] ?? null;
        abort_unless($p, 404);
        $p->loadMissing(['organization', 'person', 'manager', 'members', 'tasks.user', 'deploys.user']);
        $team = Schema::hasTable('codeit_team_tasks')
            ? TeamTask::with('assignee')->where('project_id', $id)->orderByRaw("status = 'done'")->orderBy('due_at')->limit(100)->get()->map(fn ($t) => $this->teamTaskJson($t))->values()
            : [];
        $links = collect(is_array($p->links) ? $p->links : (json_decode((string) $p->links, true) ?: []))
            ->filter(fn ($l) => is_array($l) && preg_match('#^https?://#i', (string) ($l['url'] ?? '')))->values();

        return response()->json(['data' => $this->projectJson($p) + [
            'description' => (string) $p->description,
            'person' => self::ref($p->person),
            'start_date' => optional($p->start_date)->toDateString(),
            'launched_on' => optional($p->launched_on)->toDateString(),
            'next_step' => $p->next_step,
            'next_date' => optional($p->next_date)->toDateString(),
            'links' => $links,
            'tasks' => $p->tasks->sortBy(fn ($t) => [$t->status === 'done' ? 1 : 0, $t->due_date])->map(fn ($t) => [
                'id' => $t->id, 'title' => $t->title, 'status' => $t->status, 'due_date' => optional($t->due_date)->toDateString(), 'user' => self::ref($t->user),
            ])->values(),
            'team_tasks' => $team,
            'deploys' => $p->deploys->sortByDesc('id')->take(20)->map(fn ($d) => [
                'id' => $d->id, 'version' => $d->version, 'env' => $d->env, 'status' => $d->status, 'branch' => $d->branch, 'note' => $d->note, 'created_at' => self::iso($d->created_at), 'user' => self::ref($d->user),
            ])->values(),
        ]]);
    }

    public function storeProjectTask(int $id): JsonResponse
    {
        return $this->act('admin.codeit.projects.tasks.store', ['id' => $id], request()->only(['title', 'user_id', 'due_date']) + ['status' => request('status', 'open')]);
    }

    public function updateProjectTask(int $taskId): JsonResponse
    {
        return $this->act('admin.codeit.projects.tasks.update', ['taskId' => $taskId], ['status' => request('status')]);
    }

    protected function projectJson(Project $p): array
    {
        $total = $p->relationLoaded('tasks') ? $p->tasks->count() : 0;
        $done = $p->relationLoaded('tasks') ? $p->tasks->where('status', 'done')->count() : 0;

        return [
            'id' => $p->id, 'code' => (string) $p->code, 'name' => $p->name,
            'stage' => $p->stage, 'stage_label' => trans('codeit_project::app.stages.'.$p->stage),
            'type' => $p->type, 'priority' => $p->priority,
            'client' => self::ref($p->organization),
            'manager' => self::ref($p->manager),
            'members' => $p->relationLoaded('members') ? $p->members->map(fn ($m) => self::ref($m))->values() : [],
            'value' => (float) $p->value,
            'due_date' => optional($p->due_date)->toDateString(),
            'progress' => method_exists($p, 'progress') ? (int) $p->progress() : ($total ? (int) round($done * 100 / $total) : 0),
            'tasks_open' => $total - $done, 'tasks_done' => $done,
        ];
    }

    /* ---------- team tasks ---------- */

    public function tasks(): JsonResponse
    {
        $d = $this->page('admin.codeit.team.index', [], array_filter(['who' => request('who'), 'group' => request('group')]));
        $cols = collect($d['columns'] ?? [])->map(fn ($c) => collect($c)->map(fn ($t) => $this->teamTaskJson($t))->values());

        return response()->json([
            'columns' => $cols,
            'queue' => collect($d['queue'] ?? [])->map(fn ($t) => $this->teamTaskJson($t))->values(),
            'stats' => $d['stats'] ?? [],
            'manager' => (bool) ($d['manager'] ?? false),
            'team' => collect($d['team'] ?? [])->map(fn ($u) => ['id' => $u->id, 'name' => $u->name, 'title' => $u->ci_title, 'open' => (int) $u->ci_open, 'late' => (int) $u->ci_late])->values(),
            'groups' => collect($d['groups'] ?? [])->map(fn ($g) => ['id' => $g->id, 'name' => $g->name, 'count' => (int) $g->n])->values(),
            'projects' => collect($d['myProjects'] ?? [])->values(),
        ]);
    }

    public function task(int $id): JsonResponse
    {
        $d = $this->page('admin.codeit.team.view', ['id' => $id]);
        $t = $d['task'] ?? null;
        abort_unless($t, 404);
        $files = collect($d['files'] ?? [])->map(fn ($f) => $this->teamFileJson($f));

        return response()->json(['data' => $this->teamTaskJson($t) + [
            'description' => (string) $t->description,
            'link' => $t->link,
            'department' => $d['dep'] ?? null,
            'assignee_title' => $d['title'] ?? null,
            'creator' => self::ref($t->creator),
            'project' => isset($d['project']) && $d['project'] ? ['id' => $d['project']->id, 'code' => $d['project']->code, 'name' => $d['project']->name] : null,
            'started_at' => self::iso($t->started_at), 'submitted_at' => self::iso($t->submitted_at), 'done_at' => self::iso($t->done_at),
            'files' => $files->values(),
            'project_files' => collect($d['projectFiles'] ?? [])->map(fn ($f) => $this->teamFileJson($f))->values(),
            'updates' => $t->updates->sortBy('id')->map(fn ($u) => [
                'id' => $u->id, 'type' => $u->type, 'body' => (string) $u->body, 'meta' => $u->meta, 'user' => self::ref($u->user), 'created_at' => self::iso($u->created_at),
            ])->values(),
            'can_manage' => (bool) ($d['manager'] ?? false),
            'is_mine' => (int) $t->assignee_id === $this->user()->id,
            'max_file_mb' => (int) ($d['limit'] ?? 20),
        ]]);
    }

    public function taskStatus(int $id): JsonResponse
    {
        return $this->act('admin.codeit.team.status', ['id' => $id], request()->only(['status', 'note']), fn () => $this->teamTaskJson(TeamTask::with('assignee')->find($id)));
    }

    public function taskComment(int $id): JsonResponse
    {
        return $this->act('admin.codeit.team.comment', ['id' => $id], request()->only(['body']));
    }

    public function storeTask(): JsonResponse
    {
        $in = request()->only(['title', 'description', 'link', 'priority', 'assignee_id', 'group_id', 'project_id', 'due_date', 'due_time']);
        $before = (int) TeamTask::max('id');
        $res = $this->act('admin.codeit.team.store', [], $in + ['priority' => 'normal', 'due_time' => '17:00']);
        $new = TeamTask::with('assignee')->where('id', '>', $before)->where('created_by', $this->user()->id)->latest('id')->first();
        if ($new && $res->getStatusCode() === 200) {
            $body = $res->getData(true);
            $body['data'] = $this->teamTaskJson($new);
            $res->setData($body);
        }

        return $res;
    }

    public function taskFiles(int $id): JsonResponse
    {
        return $this->act('admin.codeit.team.files.store', ['id' => $id]);
    }

    public function teamFile(int $fileId)
    {
        return $this->run('admin.codeit.team.files.download', ['fileId' => $fileId], []);
    }

    protected function teamFileJson($f): array
    {
        return ['id' => $f->id, 'name' => $f->name, 'kind' => $f->kind, 'size' => (int) $f->size, 'user' => self::ref($f->user), 'created_at' => self::iso($f->created_at),
            'url' => url('api/mobile/v1/task-files/'.$f->id)];
    }

    protected function teamTaskJson(TeamTask $t): array
    {
        return [
            'id' => $t->id, 'title' => $t->title, 'status' => $t->status, 'priority' => $t->priority,
            'due_date' => self::iso($t->due_at),
            'late' => method_exists($t, 'isLate') ? $t->isLate() : false,
            'assignee' => self::ref($t->assignee),
            'project' => $t->project_id ? ['id' => (int) $t->project_id, 'name' => (string) DB::table('projects')->where('id', $t->project_id)->value('name')] : null,
            'group_id' => $t->group_id,
        ];
    }

    /* ---------- tickets ---------- */

    public function tickets(): JsonResponse
    {
        $filters = [];
        foreach (['status', 'priority'] as $k) {
            if (request($k)) {
                $filters[$k] = [(string) request($k)];
            }
        }
        $g = $this->grid('admin.codeit.tickets.index', [], $filters, ['column' => 'updated_at', 'order' => 'desc']);
        $rows = self::ordered(Ticket::class, $g['ids'], ['organization', 'assignee', 'project', 'person']);

        return response()->json(['data' => $rows->map(fn ($t) => $this->ticketJson($t))->values(), 'meta' => $g['meta']]);
    }

    public function ticket(int $id): JsonResponse
    {
        $d = $this->page('admin.codeit.tickets.view', ['id' => $id]);
        $t = $d['ticket'] ?? null;
        abort_unless($t, 404);
        $t->loadMissing(['messages.attachments', 'hours.user']);
        $users = \Webkul\User\Models\User::pluck('name', 'id');
        $persons = \Webkul\Contact\Models\Person::whereIn('id', $t->messages->where('author_type', 'person')->pluck('author_id')->filter())->pluck('name', 'id');

        return response()->json(['data' => $this->ticketJson($t) + [
            'type' => $t->type, 'estimate' => $t->estimate === null ? null : (float) $t->estimate,
            'rating' => $t->rating, 'rating_comment' => $t->rating_comment,
            'first_response_at' => self::iso($t->first_response_at), 'resolved_at' => self::iso($t->resolved_at),
            'messages' => $t->messages->sortBy('id')->map(fn ($m) => [
                'id' => $m->id,
                'author' => $m->author_type === 'person' ? ($persons[$m->author_id] ?? 'العميل') : ($users[$m->author_id] ?? 'code it'),
                'from_client' => $m->author_type === 'person',
                'internal' => (bool) $m->is_internal,
                'body' => (string) $m->text,
                'created_at' => self::iso($m->created_at),
                'files' => $m->attachments->map(fn ($a) => ['id' => $a->id, 'name' => $a->name, 'mime' => $a->mime, 'size' => (int) $a->size, 'url' => url('api/mobile/v1/ticket-files/'.$a->id)])->values(),
            ])->values(),
            'hours' => $t->hours->sortByDesc('date')->map(fn ($h) => ['date' => optional($h->date)->toDateString(), 'hours' => (float) $h->hours, 'what' => $h->what, 'user' => self::ref($h->user)])->values(),
            'package' => isset($d['package']) && $d['package'] ? ['name' => $d['package']->name, 'hours' => (float) $d['package']->hours, 'used' => (float) ($d['packageUsed'] ?? 0)] : null,
            'users' => collect($d['users'] ?? [])->map(fn ($u) => ['id' => $u->id, 'name' => $u->name])->values(),
        ]]);
    }

    public function ticketReply(int $id): JsonResponse
    {
        $in = request()->only(['text', 'status']);
        if (request()->boolean('internal')) {
            $in['is_internal'] = 1;
            $in['internal'] = 1;
        }

        return $this->act('admin.codeit.tickets.reply', ['id' => $id], $in);
    }

    public function ticketUpdate(int $id): JsonResponse
    {
        $t = Ticket::findOrFail($id);
        $in = array_merge(['status' => $t->status, 'priority' => $t->priority, 'type' => $t->type, 'user_id' => $t->user_id, 'project_id' => $t->project_id, 'estimate' => $t->estimate],
            request()->only(['status', 'priority', 'type', 'user_id', 'project_id', 'estimate']));

        return $this->act('admin.codeit.tickets.update', ['id' => $id], $in, fn () => $this->ticketJson(Ticket::with(['organization', 'assignee', 'project', 'person'])->find($id)));
    }

    public function ticketHours(int $id): JsonResponse
    {
        return $this->act('admin.codeit.tickets.hours', ['id' => $id], request()->only(['hours', 'what', 'date']));
    }

    public function ticketFile(int $attachmentId)
    {
        return $this->run('admin.codeit.tickets.attachment', ['attachmentId' => $attachmentId], []);
    }

    protected function ticketJson(Ticket $t): array
    {
        $sla = $t->sla();

        return [
            'id' => $t->id, 'number' => $t->number, 'subject' => $t->title,
            'priority' => $t->priority, 'status' => $t->status,
            'status_label' => trans('codeit_support::app.statuses.'.$t->status),
            'client' => self::ref($t->organization), 'person' => self::ref($t->person),
            'project' => $t->project ? ['id' => $t->project->id, 'name' => $t->project->name, 'code' => $t->project->code] : null,
            'assignee' => self::ref($t->assignee),
            'sla_due_at' => $sla ? self::iso($t->response_due_at) : null,
            'sla_minutes' => $sla['minutes'] ?? null,
            'created_at' => self::iso($t->created_at), 'updated_at' => self::iso($t->updated_at),
        ];
    }

    /* ---------- invoices ---------- */

    public function invoices(): JsonResponse
    {
        $filters = request('status') ? ['status' => [(string) request('status')]] : [];
        $g = $this->grid('admin.codeit.invoices.index', [], $filters, ['column' => 'id', 'order' => 'desc']);
        $rows = self::ordered(Invoice::class, $g['ids'], ['organization', 'items', 'payments', 'project']);

        return response()->json(['data' => $rows->map(fn ($i) => $this->invoiceJson($i))->values(), 'meta' => $g['meta']]);
    }

    public function invoice(int $id): JsonResponse
    {
        $i = $this->page('admin.codeit.invoices.view', ['id' => $id])['invoice'] ?? null;
        abort_unless($i, 404);

        return response()->json(['data' => $this->invoiceJson($i) + [
            'notes' => (string) $i->notes, 'vat_rate' => (float) $i->vat_rate, 'subtotal' => $i->subtotal(), 'vat' => $i->vat(),
            'items' => $i->items->sortBy('sort')->map(fn ($x) => ['description' => $x->description, 'weeks' => (float) $x->weeks, 'amount' => (float) $x->amount])->values(),
            'payments' => $i->payments->sortByDesc('date')->map(fn ($p) => ['id' => $p->id, 'amount' => (float) $p->amount, 'date' => optional($p->date)->toDateString(), 'method' => $p->method, 'reference' => $p->reference])->values(),
            'payment_reported_at' => self::iso($i->payment_reported_at), 'payment_report_note' => $i->payment_report_note,
            'print_url' => route('admin.codeit.invoices.print', $i->id),
        ]]);
    }

    public function invoicePayment(int $id): JsonResponse
    {
        return $this->act('admin.codeit.invoices.payments.store', ['id' => $id], request()->only(['amount', 'date', 'method', 'reference']) + ['date' => now()->toDateString()]);
    }

    protected function invoiceJson(Invoice $i): array
    {
        return [
            'id' => $i->id, 'number' => $i->number, 'status' => $i->status,
            'client' => self::ref($i->organization), 'project' => self::ref($i->project),
            'total' => $i->total(), 'paid' => $i->paid(), 'remaining' => $i->remaining(),
            'issue_date' => optional($i->issue_date)->toDateString(), 'due_date' => optional($i->due_date)->toDateString(),
        ];
    }
}
