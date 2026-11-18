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
        ];

        return response()->json(['data' => collect($all)->filter(fn ($r) => RouteGate::can($r))->keys()->values()]);
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
}
