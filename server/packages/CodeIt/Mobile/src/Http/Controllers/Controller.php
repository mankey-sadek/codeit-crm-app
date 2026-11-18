<?php

namespace CodeIt\Mobile\Http\Controllers;

use CodeIt\Mobile\Support\RouteGate;
use Illuminate\Contracts\View\View;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Routing\Controller as Base;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Route;
use Symfony\Component\HttpFoundation\Response;
use Webkul\User\Models\User;

/**
 * Base for the mobile API. Two ways to reach the CRM:
 *  - page():  runs the same controller action as a web page and returns the data it hands to the view,
 *             so lists and details follow the exact same visibility rules as the web.
 *  - act():   runs a web form action (save, approve, reply...) and answers { ok, message }.
 * Both check the role permission of that route first, like the web does.
 */
abstract class Controller extends Base
{
    protected function user(): User
    {
        return auth()->guard('user')->user();
    }

    /** @return array<string, mixed> */
    protected function page(string $routeName, array $params = [], array $query = []): array
    {
        $res = $this->run($routeName, $params, $query);
        if ($res instanceof View) {
            return $res->getData();
        }
        if ($res instanceof JsonResponse) {
            return (array) $res->getData(true);
        }
        if ($res instanceof RedirectResponse) {
            abort(404);
        }

        return is_array($res) ? $res : [];
    }

    protected function act(string $routeName, array $params = [], array $input = [], ?\Closure $data = null): JsonResponse
    {
        $res = $this->run($routeName, $params, $input);
        $session = session();
        if ($res instanceof JsonResponse && $res->getStatusCode() >= 400) {
            return $res;
        }
        $error = $session->get('error') ?? $session->get('warning');
        $errors = $session->get('errors');
        if ($errors instanceof \Illuminate\Support\ViewErrorBag) {
            $errors = $errors->getBag('default');
        }
        if ($errors instanceof \Illuminate\Support\MessageBag && $errors->any()) {
            return response()->json(['error' => ['code' => 'validation', 'message' => $errors->first(), 'details' => $errors->toArray()]], 422);
        }
        if ($error && ! $session->get('success')) {
            return response()->json(['error' => ['code' => 'rejected', 'message' => is_string($error) ? $error : trans('codeit_brand::api.validation')]], 422);
        }
        $body = ['ok' => true, 'message' => (string) ($session->get('success') ?? '')];
        if ($res instanceof JsonResponse) {
            $j = $res->getData(true);
            $body['message'] = $body['message'] ?: (string) ($j['message'] ?? '');
            $body['result'] = $j['data'] ?? $j;
        }
        if ($data) {
            $body['data'] = $data();
        }

        return response()->json($body);
    }

    protected function run(string $routeName, array $params, array $input): mixed
    {
        $route = Route::getRoutes()->getByName($routeName);
        abort_unless($route, 404);
        (new RouteGate)->authorizeRoute($routeName);

        $request = request();
        foreach ($input as $k => $v) {
            $request->query->set($k, $v);
        }
        $request->merge($input);
        $route->bind($request);
        foreach ($params as $k => $v) {
            $route->setParameter($k, $v);
        }
        $request->setRouteResolver(fn () => $route);

        [$class, $method] = explode('@', $route->getActionName());
        $controller = app($class);

        return app()->call([$controller, $method], $params);
    }

    /**
     * A web list (Krayin DataGrid) as the app needs it: the ids the person may see, in order,
     * with search / filters / paging, plus the raw rows for list-only columns.
     */
    protected function grid(string $routeName, array $params = [], array $filters = [], ?array $sort = null, int $per = 20): array
    {
        $page = max(1, (int) request('page', 1));
        $q = ['pagination' => ['page' => $page, 'per_page' => in_array($per, [10, 20, 30, 40, 50], true) ? $per : 20]];
        $search = trim((string) request('q'));
        if ($search !== '') {
            $filters['all'] = [$search];
        }
        if ($filters) {
            $q['filters'] = $filters;
        }
        if ($sort) {
            $q['sort'] = $sort;
        }
        $old = request()->headers->get('X-Requested-With');
        request()->headers->set('X-Requested-With', 'XMLHttpRequest');
        try {
            $d = $this->page($routeName, $params, $q);
        } finally {
            request()->headers->set('X-Requested-With', $old);
        }
        $rows = collect($d['records'] ?? []);

        return [
            'ids' => $rows->pluck('id')->map(fn ($v) => (int) $v)->all(),
            'rows' => $rows->keyBy('id'),
            'meta' => [
                'total' => (int) ($d['meta']['total'] ?? $rows->count()),
                'current_page' => (int) ($d['meta']['current_page'] ?? 1),
                'last_page' => (int) ($d['meta']['last_page'] ?? 1),
            ],
        ];
    }

    /** Models for grid ids, in the grid's order. */
    protected static function ordered(string $model, array $ids, array $with = [])
    {
        if (! $ids) {
            return collect();
        }
        $byId = $model::with($with)->whereIn('id', $ids)->get()->keyBy('id');

        return collect($ids)->map(fn ($id) => $byId[$id] ?? null)->filter()->values();
    }

    protected static function plain($v): string
    {
        return trim(html_entity_decode(strip_tags((string) $v), ENT_QUOTES | ENT_HTML5, 'UTF-8'));
    }

    /* ---------- shaping helpers ---------- */

    protected static function ref($model, string $name = 'name'): ?array
    {
        if (! $model) {
            return null;
        }

        return ['id' => (int) $model->id, 'name' => (string) ($model->{$name} ?? '')];
    }

    protected static function iso($v): ?string
    {
        if (! $v) {
            return null;
        }

        return Carbon::parse($v)->toIso8601String();
    }

    protected static function paged($paginator, \Closure $map): array
    {
        return [
            'data' => collect($paginator->items())->map($map)->values(),
            'meta' => ['total' => $paginator->total(), 'current_page' => $paginator->currentPage(), 'last_page' => $paginator->lastPage()],
        ];
    }

    protected function streamFile(string $disk, string $path, string $name, ?string $mime = null): Response
    {
        $fs = \Illuminate\Support\Facades\Storage::disk($disk);
        abort_unless($path !== '' && $fs->exists($path), 404);

        return $fs->response($path, $name, array_filter(['Content-Type' => $mime]), 'inline');
    }
}
