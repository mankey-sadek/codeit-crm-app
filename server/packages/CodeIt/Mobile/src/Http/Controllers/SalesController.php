<?php

namespace CodeIt\Mobile\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Webkul\Activity\Models\Activity;
use Webkul\Contact\Models\Organization;
use Webkul\Contact\Models\Person;
use Webkul\Lead\Models\Lead;
use Webkul\Lead\Models\Pipeline;
use Webkul\Product\Models\Product;
use Webkul\Quote\Models\Quote;

/** Leads (pipeline), contacts, activities, quotes and products: Krayin's own data and rules. */
class SalesController extends Controller
{
    public function pipelines(): JsonResponse
    {
        (new \CodeIt\Mobile\Support\RouteGate)->authorizeRoute('admin.leads.index');

        return response()->json(['data' => Pipeline::with(['stages' => fn ($q) => $q->orderBy('sort_order')])->orderByDesc('is_default')->get()
            ->map(fn ($p) => [
                'id' => $p->id, 'name' => $p->name, 'is_default' => (bool) $p->is_default, 'rotten_days' => (int) $p->rotten_days,
                'stages' => $p->stages->map(fn ($s) => ['id' => $s->id, 'code' => $s->code, 'name' => $s->name, 'probability' => (int) $s->probability])->values(),
            ])]);
    }

    public function leads(): JsonResponse
    {
        $filters = [];
        if ($stage = (int) request('stage')) {
            $filters['lead_pipeline_stage_id'] = [$stage];
        }
        if ($pipe = (int) request('pipeline')) {
            request()->query->set('pipeline_id', $pipe);
        }
        $g = $this->grid('admin.leads.index', [], $filters, ['column' => 'created_at', 'order' => 'desc']);
        $leads = self::ordered(Lead::class, $g['ids'], ['person', 'stage', 'user', 'person.organization', 'tags']);

        return response()->json(['data' => $leads->map(fn ($l) => $this->leadJson($l))->values(), 'meta' => $g['meta']]);
    }

    /** Board: every open stage of a pipeline with its leads (first 30 each). */
    public function board(): JsonResponse
    {
        (new \CodeIt\Mobile\Support\RouteGate)->authorizeRoute('admin.leads.index');
        $pipe = Pipeline::with(['stages' => fn ($q) => $q->orderBy('sort_order')])->find((int) request('pipeline'))
            ?? Pipeline::with(['stages' => fn ($q) => $q->orderBy('sort_order')])->where('is_default', 1)->first();
        abort_unless($pipe, 404);
        $users = bouncer()->getAuthorizedUserIds();
        $q = trim((string) request('q'));

        $stages = $pipe->stages->map(function ($s) use ($users, $q) {
            $base = Lead::where('lead_pipeline_stage_id', $s->id)
                ->when($users, fn ($w) => $w->whereIn('user_id', $users))
                ->when($q !== '', fn ($w) => $w->where('title', 'like', '%'.$q.'%'));

            return [
                'id' => $s->id, 'code' => $s->code, 'name' => $s->name, 'probability' => (int) $s->probability,
                'count' => (clone $base)->count(),
                'value' => (float) (clone $base)->sum('lead_value'),
                'leads' => (clone $base)->with(['person', 'stage', 'user', 'tags'])->orderByDesc('updated_at')->limit(30)->get()->map(fn ($l) => $this->leadJson($l))->values(),
            ];
        });

        return response()->json(['pipeline' => ['id' => $pipe->id, 'name' => $pipe->name], 'stages' => $stages]);
    }

    public function lead(int $id): JsonResponse
    {
        $lead = $this->page('admin.leads.view', ['id' => $id])['lead'] ?? null;
        abort_unless($lead, 404);
        $lead->load(['person.organization', 'stage', 'pipeline.stages', 'user', 'source', 'type', 'tags', 'products', 'activities.user']);

        return response()->json(['data' => $this->leadJson($lead, true)]);
    }

    public function leadStage(int $id): JsonResponse
    {
        request()->validate(['stage_id' => ['required', 'integer']]);

        return $this->act('admin.leads.stage.update', ['id' => $id], array_filter([
            'lead_pipeline_stage_id' => (int) request('stage_id'),
            'lost_reason' => request('lost_reason'),
            'closed_at' => request('closed_at'),
        ], fn ($v) => $v !== null), fn () => $this->leadJson(Lead::with(['person', 'stage', 'user', 'tags'])->find($id)));
    }

    protected function leadJson(Lead $l, bool $full = false): array
    {
        $person = $l->person;
        $out = [
            'id' => $l->id,
            'title' => $l->title,
            'value' => (float) $l->lead_value,
            'status' => $l->status === null ? 'open' : ((int) $l->status === 1 ? 'won' : 'lost'),
            'stage' => $l->stage ? ['id' => $l->stage->id, 'code' => $l->stage->code, 'name' => $l->stage->name] : null,
            'person' => self::ref($person),
            'organization' => self::ref($person?->organization),
            'owner' => self::ref($l->user),
            'phone' => collect($person?->contact_numbers ?? [])->pluck('value')->first(),
            'email' => collect($person?->emails ?? [])->pluck('value')->first(),
            'expected_close_date' => optional($l->expected_close_date)->toDateString() ?? ($l->expected_close_date ?: null),
            'rotten_days' => (int) ($l->rotten_days ?? 0),
            'created_at' => self::iso($l->created_at),
            'tags' => $l->tags?->pluck('name')->values() ?? [],
        ];
        if ($full) {
            $out += [
                'description' => (string) $l->description,
                'source' => $l->source?->name,
                'type' => $l->type?->name,
                'lost_reason' => $l->lost_reason,
                'pipeline' => $l->pipeline ? ['id' => $l->pipeline->id, 'name' => $l->pipeline->name,
                    'stages' => $l->pipeline->stages->sortBy('sort_order')->map(fn ($s) => ['id' => $s->id, 'code' => $s->code, 'name' => $s->name, 'probability' => (int) $s->probability])->values()] : null,
                'products' => $l->products->map(fn ($p) => ['name' => $p->product?->name ?? $p->name, 'quantity' => (float) $p->quantity, 'price' => (float) $p->price, 'total' => (float) $p->amount])->values(),
                'quotes' => DB::table('lead_quotes')->join('quotes', 'quotes.id', '=', 'lead_quotes.quote_id')->where('lead_id', $l->id)->get(['quotes.id', 'quotes.subject', 'quotes.grand_total'])->map(fn ($q) => ['id' => (int) $q->id, 'subject' => $q->subject, 'grand_total' => (float) $q->grand_total])->values(),
                'activities' => tap($l->activities->sortByDesc('created_at')->take(50), fn ($r) => $this->attachLinks($r))->map(fn ($a) => $this->activityJson($a))->values(),
            ];
        }

        return $out;
    }

    /* ---------- contacts ---------- */

    public function persons(): JsonResponse
    {
        $g = $this->grid('admin.contacts.persons.index', [], [], ['column' => 'id', 'order' => 'desc']);
        $rows = self::ordered(Person::class, $g['ids'], ['organization']);
        $counts = Lead::whereIn('person_id', $g['ids'] ?: [0])->select('person_id', DB::raw('count(*) n'))->groupBy('person_id')->pluck('n', 'person_id');

        return response()->json(['data' => $rows->map(fn ($p) => $this->personJson($p) + ['leads_count' => (int) ($counts[$p->id] ?? 0)])->values(), 'meta' => $g['meta']]);
    }

    public function person(int $id): JsonResponse
    {
        $p = $this->page('admin.contacts.persons.view', ['id' => $id])['person'] ?? null;
        abort_unless($p, 404);
        $p->load(['organization', 'leads.stage', 'activities.user', 'tags']);
        $users = bouncer()->getAuthorizedUserIds();

        return response()->json(['data' => $this->personJson($p) + [
            'leads' => $p->leads->filter(fn ($l) => ! $users || in_array($l->user_id, $users))->map(fn ($l) => ['id' => $l->id, 'title' => $l->title, 'value' => (float) $l->lead_value, 'stage' => $l->stage?->name])->values(),
            'activities' => tap($p->activities->sortByDesc('created_at')->take(30), fn ($r) => $this->attachLinks($r))->map(fn ($a) => $this->activityJson($a))->values(),
            'tags' => $p->tags->pluck('name'),
        ]]);
    }

    protected function personJson(Person $p): array
    {
        return [
            'id' => $p->id, 'name' => $p->name, 'job_title' => $p->job_title,
            'emails' => collect($p->emails ?? [])->pluck('value')->filter()->values(),
            'phones' => collect($p->contact_numbers ?? [])->pluck('value')->filter()->values(),
            'organization' => self::ref($p->organization),
        ];
    }

    public function organizations(): JsonResponse
    {
        $g = $this->grid('admin.contacts.organizations.index', [], [], ['column' => 'id', 'order' => 'desc']);
        $rows = self::ordered(Organization::class, $g['ids']);
        $counts = Person::whereIn('organization_id', $g['ids'] ?: [0])->select('organization_id', DB::raw('count(*) n'))->groupBy('organization_id')->pluck('n', 'organization_id');

        return response()->json(['data' => $rows->map(fn ($o) => $this->orgJson($o) + ['persons_count' => (int) ($counts[$o->id] ?? 0)])->values(), 'meta' => $g['meta']]);
    }

    public function organization(int $id): JsonResponse
    {
        (new \CodeIt\Mobile\Support\RouteGate)->authorizeRoute('admin.contacts.organizations.view');
        $o = Organization::with('persons')->findOrFail($id);
        $users = bouncer()->getAuthorizedUserIds();
        abort_if($users && $o->user_id && ! in_array($o->user_id, $users), 404);

        $extra = ['persons' => $o->persons->map(fn ($p) => $this->personJson($p))->values()];
        if (\Illuminate\Support\Facades\Schema::hasTable('projects')) {
            $extra['projects'] = DB::table('projects')->where('organization_id', $id)->orderByDesc('id')->get(['id', 'code', 'name', 'stage'])->values();
        }

        return response()->json(['data' => $this->orgJson($o) + $extra]);
    }

    protected function orgJson(Organization $o): array
    {
        $addr = $o->address;
        $addr = is_array($addr) ? implode('، ', array_filter([$addr['address'] ?? null, $addr['city'] ?? null, $addr['country'] ?? null])) : (string) $addr;

        return ['id' => $o->id, 'name' => $o->name, 'address' => $addr];
    }

    /* ---------- activities ---------- */

    public function activities(): JsonResponse
    {
        (new \CodeIt\Mobile\Support\RouteGate)->authorizeRoute('admin.activities.index');
        $from = request('from') ? \Carbon\Carbon::parse(request('from')) : now()->startOfDay()->subDays(1);
        $to = request('to') ? \Carbon\Carbon::parse(request('to')) : now()->endOfDay()->addDays(14);
        $users = bouncer()->getAuthorizedUserIds();
        $rows = Activity::with(['user'])
            ->whereIn('type', ['call', 'meeting', 'lunch', 'task'])
            ->when($users, fn ($q) => $q->where(fn ($w) => $w->whereIn('user_id', $users)->orWhereHas('participants', fn ($p) => $p->whereIn('user_id', $users))))
            ->when(request('done') !== null, fn ($q) => $q->where('is_done', (int) request('done')))
            ->whereBetween('schedule_from', [$from, $to])
            ->orderBy('schedule_from')->limit(300)->get();
        $this->attachLinks($rows);

        return response()->json(['data' => $rows->map(fn ($a) => $this->activityJson($a))->values()]);
    }

    public function storeActivity(): JsonResponse
    {
        $d = request()->validate([
            'type' => ['required', 'in:call,meeting,lunch,note,task'],
            'title' => ['required_unless:type,note', 'nullable', 'string', 'max:190'],
            'comment' => ['nullable', 'string', 'max:5000'],
            'schedule_from' => ['required_unless:type,note', 'nullable', 'date'],
            'schedule_to' => ['required_unless:type,note', 'nullable', 'date'],
            'lead_id' => ['nullable', 'integer'],
            'person_id' => ['nullable', 'integer'],
            'location' => ['nullable', 'string', 'max:190'],
        ]);
        $input = array_filter($d, fn ($v) => $v !== null) + ['participants' => ['users' => [], 'persons' => []]];
        if ($d['type'] === 'note') {
            $input['title'] = $d['title'] ?? 'ملاحظة';
        }

        return $this->act('admin.activities.store', [], $input);
    }

    public function updateActivity(int $id): JsonResponse
    {
        $a = Activity::findOrFail($id);
        $input = array_filter(request()->only(['is_done', 'title', 'comment', 'schedule_from', 'schedule_to']), fn ($v) => $v !== null);

        return $this->act('admin.activities.update', ['id' => $id], $input + ['type' => $a->type], function () use ($id) {
            $a = Activity::with('user')->find($id);
            $this->attachLinks(collect([$a]));

            return $this->activityJson($a);
        });
    }

    /**
     * Lead + person of each activity, read from the pivot tables directly.
     * (Eager loading Activity::leads/persons breaks on the live models' column scopes.)
     */
    protected function attachLinks($rows): void
    {
        $ids = $rows->pluck('id')->all();
        if (! $ids) {
            return;
        }
        $leads = DB::table('lead_activities')->join('leads', 'leads.id', '=', 'lead_activities.lead_id')
            ->whereIn('activity_id', $ids)->get(['activity_id', 'leads.id', 'leads.title'])->keyBy('activity_id');
        $persons = DB::table('person_activities')->join('persons', 'persons.id', '=', 'person_activities.person_id')
            ->whereIn('activity_id', $ids)->get(['activity_id', 'persons.id', 'persons.name'])->keyBy('activity_id');
        foreach ($rows as $a) {
            $l = $leads->get($a->id);
            $p = $persons->get($a->id);
            $a->setAttribute('ci_lead', $l ? ['id' => (int) $l->id, 'name' => (string) $l->title] : null);
            $a->setAttribute('ci_person', $p ? ['id' => (int) $p->id, 'name' => (string) $p->name] : null);
        }
    }

    /** Krayin writes system activities with the English field name ("تم تحديث Stage"); say it in Arabic. */
    public static function fieldsAr(string $t): string
    {
        return strtr($t, [
            'Estimated Lead Value' => 'القيمة المتوقعة', 'Contact Numbers' => 'أرقام التليفون', 'Expected Close Date' => 'تاريخ الإغلاق المتوقع',
            'Sales Owner' => 'المسؤول', 'Job Title' => 'الوظيفة', 'Pipeline' => 'مسار البيع', 'Stage' => 'المرحلة', 'Source' => 'المصدر',
            'Emails' => 'الإيميل', 'Organization' => 'الشركة', 'Person' => 'جهة الاتصال', 'Description' => 'الوصف', 'Address' => 'العنوان',
            'Title' => 'العنوان', 'Type' => 'النوع', 'Name' => 'الاسم', 'Products' => 'المنتجات', 'Tags' => 'الوسوم',
        ]);
    }

    protected function activityJson(Activity $a): array
    {
        return [
            'id' => $a->id, 'type' => $a->type, 'title' => self::fieldsAr((string) $a->title), 'comment' => (string) $a->comment,
            'schedule_from' => self::iso($a->schedule_from), 'schedule_to' => self::iso($a->schedule_to),
            'is_done' => (bool) $a->is_done, 'location' => $a->location,
            'user' => self::ref($a->user),
            'lead' => $a->getAttribute('ci_lead'),
            'person' => $a->getAttribute('ci_person'),
            'created_at' => self::iso($a->created_at),
        ];
    }

    /* ---------- quotes + products ---------- */

    public function quotes(): JsonResponse
    {
        $g = $this->grid('admin.quotes.index', [], [], ['column' => 'id', 'order' => 'desc']);
        $rows = self::ordered(Quote::class, $g['ids'], ['person']);

        return response()->json(['data' => $rows->map(fn ($q) => $this->quoteJson($q))->values(), 'meta' => $g['meta']]);
    }

    public function quote(int $id): JsonResponse
    {
        $q = $this->page('admin.quotes.edit', ['id' => $id])['quote'] ?? null;
        abort_unless($q, 404);
        $q->load(['items', 'person', 'user']);

        return response()->json(['data' => $this->quoteJson($q) + [
            'description' => (string) $q->description,
            'sub_total' => (float) $q->sub_total, 'discount' => (float) $q->discount_amount, 'tax' => (float) $q->tax_amount, 'adjustment' => (float) $q->adjustment_amount,
            'owner' => self::ref($q->user),
            'items' => $q->items->map(fn ($i) => ['name' => $i->name, 'sku' => $i->sku, 'quantity' => (float) $i->quantity, 'price' => (float) $i->price, 'total' => (float) $i->total])->values(),
            'print_url' => \Illuminate\Support\Facades\Route::has('admin.quotes.print') ? route('admin.quotes.print', $q->id) : null,
        ]]);
    }

    protected function quoteJson(Quote $q): array
    {
        return [
            'id' => $q->id, 'subject' => $q->subject, 'grand_total' => (float) $q->grand_total,
            'expired_at' => self::iso($q->expired_at), 'person' => self::ref($q->person), 'lead' => self::ref(DB::table('lead_quotes')->join('leads', 'leads.id', '=', 'lead_quotes.lead_id')->where('quote_id', $q->id)->select('leads.id', 'leads.title')->first(), 'title'),
        ];
    }

    public function products(): JsonResponse
    {
        $g = $this->grid('admin.products.index', [], [], ['column' => 'id', 'order' => 'desc']);
        $rows = self::ordered(Product::class, $g['ids']);

        return response()->json(['data' => $rows->map(fn ($p) => ['id' => $p->id, 'name' => $p->name, 'sku' => $p->sku, 'price' => (float) $p->price, 'quantity' => (float) $p->quantity, 'description' => (string) $p->description])->values(), 'meta' => $g['meta']]);
    }
}
