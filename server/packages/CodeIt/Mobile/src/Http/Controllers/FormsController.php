<?php

namespace CodeIt\Mobile\Http\Controllers;

use CodeIt\Billing\Models\Invoice;
use CodeIt\Project\Models\Project;
use CodeIt\Support\Models\SupportPackage;
use CodeIt\Support\Models\Ticket;
use CodeIt\Team\Models\Task as TeamTask;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Webkul\Contact\Models\Organization;
use Webkul\Contact\Models\Person;
use Webkul\Lead\Models\Lead;

/**
 * Create / edit forms for the app. Every save goes through the web form action of the CRM (same
 * validation, permissions, events and e-mails as the web); this only shapes the input and answers
 * with the id of what was created so the app can open it.
 */
class FormsController extends Controller
{
    /** Choices for the app's pickers (only what the person's forms need). */
    public function options(): JsonResponse
    {
        $users = DB::table('users')->where('status', 1)->orderBy('name')->get(['id', 'name']);
        $out = [
            'users' => $users,
            'organizations' => DB::table('organizations')->whereNotNull('name')->orderBy('name')->limit(1000)->get(['id', 'name']),
            'persons' => DB::table('persons')->orderBy('name')->limit(2000)->get(['id', 'name', 'organization_id']),
            'lead_sources' => DB::table('lead_sources')->orderBy('id')->get(['id', 'name']),
            'lead_types' => DB::table('lead_types')->orderBy('id')->get(['id', 'name']),
            'pipelines' => DB::table('lead_pipelines')->orderByDesc('is_default')->get(['id', 'name', 'is_default'])->map(fn ($p) => [
                'id' => $p->id, 'name' => $p->name, 'is_default' => (bool) $p->is_default,
                'stages' => DB::table('lead_pipeline_stages')->where('lead_pipeline_id', $p->id)->orderBy('sort_order')->get(['id', 'code', 'name']),
            ]),
        ];
        if (Schema::hasTable('projects')) {
            $out['projects'] = DB::table('projects')->orderBy('name')->get(['id', 'code', 'name', 'organization_id']);
            $out['project_types'] = Project::TYPES;
            $out['project_stages'] = Project::STAGES;
            $out['project_priorities'] = Project::PRIORITIES;
        }
        if (class_exists(Ticket::class)) {
            $out['ticket_types'] = Ticket::TYPES;
            $out['ticket_priorities'] = Ticket::PRIORITIES;
        }
        if (class_exists(TeamTask::class)) {
            $out['task_priorities'] = TeamTask::PRIORITIES;
            $out['groups'] = DB::table('groups')->orderBy('name')->get(['id', 'name']);
        }

        return response()->json(['data' => $out]);
    }

    /* ------------------------------------------------------------------ sales */

    public function storePerson(): JsonResponse
    {
        $in = $this->contactInput('persons') + array_filter([
            'job_title' => request('job_title'),
            'organization_id' => request('organization_id'),
        ]);

        return $this->created('admin.contacts.persons.store', $in, Person::class);
    }

    public function storeOrganization(): JsonResponse
    {
        $in = ['entity_type' => 'organizations', 'name' => trim((string) request('name'))];
        if (filled(request('address'))) {
            $in['address'] = ['address' => (string) request('address'), 'city' => (string) request('city', ''), 'country' => 'EG', 'state' => '', 'postcode' => ''];
        }

        return $this->created('admin.contacts.organizations.store', $in, Organization::class);
    }

    public function storeLead(): JsonResponse
    {
        $in = [
            'entity_type' => 'leads',
            'title' => trim((string) request('title')),
            'description' => (string) request('description', ''),
            'lead_value' => (float) request('lead_value', 0),
            'lead_source_id' => request('lead_source_id'),
            'lead_type_id' => request('lead_type_id'),
            'user_id' => request('user_id') ?: $this->user()->id,
            'expected_close_date' => request('expected_close_date'),
            'lead_pipeline_stage_id' => request('lead_pipeline_stage_id'),
            'lead_pipeline_id' => request('lead_pipeline_id'),
        ];
        if ($pid = (int) request('person_id')) {
            $in['person'] = ['id' => $pid];
        } else {
            // new contact typed in the lead form
            $p = $this->contactInput('persons', 'person_');
            unset($p['entity_type']);
            $in['person'] = $p + array_filter(['organization_id' => request('organization_id')]);
        }

        return $this->created('admin.leads.store', array_filter($in, fn ($v) => $v !== null && $v !== ''), Lead::class);
    }

    /** name / e-mail / phone in the shape of Krayin's attribute form. */
    protected function contactInput(string $entity, string $prefix = ''): array
    {
        $in = ['entity_type' => $entity, 'name' => trim((string) request($prefix.'name'))];
        $email = trim((string) request($prefix.'email'));
        $phone = trim((string) request($prefix.'phone'));
        $in['emails'] = [['value' => $email, 'label' => 'work']];
        if ($phone !== '') {
            $in['contact_numbers'] = [['value' => $phone, 'label' => 'work']];
        }

        return $in;
    }

    /* ------------------------------------------------------------------ work */

    public function storeTicket(): JsonResponse
    {
        $in = request()->only(['organization_id', 'person_id', 'project_id', 'user_id', 'type', 'priority', 'title', 'text']);

        return $this->created('admin.codeit.tickets.store', $in + ['type' => 'question', 'priority' => 'normal'], Ticket::class);
    }

    public function projectForm(int $id): JsonResponse
    {
        $p = $this->page('admin.codeit.projects.edit', ['id' => $id])['project'] ?? null;
        abort_unless($p instanceof Project, 404);
        $links = collect(is_array($p->links) ? $p->links : (json_decode((string) $p->links, true) ?: []))
            ->map(fn ($l) => ($l['label'] ?? '') && ($l['label'] ?? '') !== ($l['url'] ?? '') ? $l['label'].' | '.$l['url'] : ($l['url'] ?? ''))
            ->filter()->implode("\n");

        return response()->json(['data' => [
            'id' => $p->id, 'code' => $p->code, 'name' => $p->name, 'description' => (string) $p->description,
            'organization_id' => $p->organization_id, 'person_id' => $p->person_id, 'lead_id' => $p->lead_id, 'user_id' => $p->user_id,
            'type' => $p->type, 'priority' => $p->priority, 'stage' => $p->stage, 'value' => (float) $p->value,
            'start_date' => optional($p->start_date)->toDateString(), 'due_date' => optional($p->due_date)->toDateString(),
            'launched_on' => optional($p->launched_on)->toDateString(), 'next_step' => $p->next_step,
            'next_date' => optional($p->next_date)->toDateString(), 'links_text' => $links,
            'members' => $p->members()->pluck('users.id')->map(fn ($v) => (int) $v)->values(),
        ]]);
    }

    public function storeProject(): JsonResponse
    {
        return $this->created('admin.codeit.projects.store', $this->projectInput(), Project::class);
    }

    public function updateProject(int $id): JsonResponse
    {
        return $this->act('admin.codeit.projects.update', ['id' => $id], $this->projectInput(), fn () => ['id' => $id]);
    }

    protected function projectInput(): array
    {
        return request()->only(['name', 'description', 'organization_id', 'person_id', 'lead_id', 'user_id', 'type', 'priority', 'stage',
            'value', 'start_date', 'due_date', 'launched_on', 'next_step', 'next_date', 'links_text', 'members'])
            + ['type' => 'web', 'priority' => 'normal', 'stage' => 'discovery', 'members' => []];
    }

    public function invoiceForm(int $id): JsonResponse
    {
        $res = $this->run('admin.codeit.invoices.edit', ['id' => $id], []);
        if (! $res instanceof \Illuminate\Contracts\View\View) {
            $msg = session('error') ?? session('warning') ?? 'الفاتورة دي مينفعش تتعدل.';

            return response()->json(['error' => ['code' => 'locked', 'message' => is_string($msg) ? $msg : 'الفاتورة دي مينفعش تتعدل.']], 422);
        }
        $d = $res->getData();
        $inv = $d['invoice'];

        return response()->json(['data' => [
            'id' => $inv->id, 'number' => $inv->number, 'organization_id' => $inv->organization_id, 'project_id' => $inv->project_id,
            'quote_id' => $inv->quote_id, 'issue_date' => optional($inv->issue_date)->toDateString(),
            'due_date' => optional($inv->due_date)->toDateString(), 'vat_rate' => (float) $inv->vat_rate, 'notes' => (string) $inv->notes,
            'items' => collect($d['items'] ?? $inv->items)->map(fn ($i) => [
                'description' => (string) data_get($i, 'description'), 'weeks' => data_get($i, 'weeks'), 'amount' => (float) data_get($i, 'amount'),
            ])->filter(fn ($i) => $i['description'] !== '' || $i['amount'] > 0)->values(),
        ]]);
    }

    public function storeInvoice(): JsonResponse
    {
        return $this->created('admin.codeit.invoices.store', $this->invoiceInput(), Invoice::class);
    }

    public function updateInvoice(int $id): JsonResponse
    {
        return $this->act('admin.codeit.invoices.update', ['id' => $id], $this->invoiceInput(), fn () => ['id' => $id]);
    }

    protected function invoiceInput(): array
    {
        $in = request()->only(['organization_id', 'project_id', 'quote_id', 'issue_date', 'due_date', 'vat_rate', 'notes', 'items']);
        $in['items'] = array_values(array_filter((array) ($in['items'] ?? []), 'is_array'));

        return $in + ['issue_date' => now()->toDateString(), 'vat_rate' => 0.14];
    }

    public function taskForm(int $id): JsonResponse
    {
        $t = $this->page('admin.codeit.team.edit', ['id' => $id])['task'] ?? null;
        abort_unless($t instanceof TeamTask, 404);

        return response()->json(['data' => [
            'id' => $t->id, 'title' => $t->title, 'description' => (string) $t->description, 'link' => $t->link, 'priority' => $t->priority,
            'assignee_id' => $t->assignee_id, 'group_id' => $t->group_id, 'project_id' => $t->project_id,
            // in the team's time zone, like the web form
            'due_date' => $t->due_at?->copy()->setTimezone(TeamTask::TZ)->toDateString(), 'due_time' => $t->due_at?->copy()->setTimezone(TeamTask::TZ)->format('H:i'),
        ]]);
    }

    public function updateTask(int $id): JsonResponse
    {
        $in = request()->only(['title', 'description', 'link', 'priority', 'assignee_id', 'group_id', 'project_id', 'due_date', 'due_time']);

        return $this->act('admin.codeit.team.update', ['id' => $id], $in + ['priority' => 'normal', 'due_time' => '17:00'], fn () => ['id' => $id]);
    }

    /* ------------------------------------------------------------------ support packages */

    public function packages(): JsonResponse
    {
        $d = $this->page('admin.codeit.packages.index');
        $used = collect($d['used'] ?? []);

        return response()->json(['data' => collect($d['packages'] ?? [])->map(fn (SupportPackage $p) => [
            'id' => $p->id, 'name' => $p->name, 'organization' => self::ref($p->organization), 'project' => self::ref($p->project),
            'hours' => (float) $p->hours, 'daily_hours' => (float) $p->daily_hours, 'used' => round((float) ($used[$p->id] ?? 0), 2),
            'price' => (float) $p->price, 'is_free' => (bool) $p->is_free, 'is_active' => (bool) $p->is_active,
            'period_start' => optional($p->period_start)->toDateString(), 'renew_on' => optional($p->renew_on)->toDateString(),
        ])->values()]);
    }

    public function packageAction(int $id, string $action): JsonResponse
    {
        return $this->act($action === 'renew' ? 'admin.codeit.packages.renew' : 'admin.codeit.packages.toggle', ['id' => $id]);
    }

    /* ------------------------------------------------------------------ helpers */

    /** Runs a web "create" action and answers with the new record's id. */
    protected function created(string $route, array $input, string $model): JsonResponse
    {
        $before = (int) $model::max('id');
        $res = $this->act($route, [], $input);
        if ($res->getStatusCode() === 200) {
            $id = (int) $model::where('id', '>', $before)->max('id');
            $body = $res->getData(true);
            $body['data'] = ['id' => $id ?: null];
            $res->setData($body);
        }

        return $res;
    }
}
