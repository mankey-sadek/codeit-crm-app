<?php

namespace CodeIt\Mobile\Http\Controllers;

use CodeIt\Careers\Models\JobApplication;
use Illuminate\Http\JsonResponse;

/** Job applications from the careers page. CV files open through the CRM's view-only viewer rules. */
class CareersController extends Controller
{
    public function index(): JsonResponse
    {
        $filters = request('status') ? ['status' => [(string) request('status')]] : [];
        $g = $this->grid('admin.codeit.careers.index', [], $filters, ['column' => 'id', 'order' => 'desc']);
        $rows = self::ordered(JobApplication::class, $g['ids'], ['files']);

        return response()->json(['data' => $rows->map(fn ($a) => $this->appJson($a))->values(), 'meta' => $g['meta'],
            'statuses' => collect(JobApplication::STATUSES)->mapWithKeys(fn ($s) => [$s => trans('codeit_careers::app.statuses.'.$s)])]);
    }

    public function show(int $id): JsonResponse
    {
        $a = $this->page('admin.codeit.careers.view', ['id' => $id])['application'] ?? null;
        abort_unless($a, 404);

        return response()->json(['data' => $this->appJson($a, true)]);
    }

    public function update(int $id): JsonResponse
    {
        $a = JobApplication::findOrFail($id);

        return $this->act('admin.codeit.careers.update', ['id' => $id], ['status' => request('status', $a->status), 'notes' => request('notes', $a->notes)],
            fn () => $this->appJson(JobApplication::with('files')->find($id)));
    }

    public function file(int $id, int $fileId)
    {
        return $this->run('admin.codeit.careers.file', ['id' => $id, 'fileId' => $fileId], []);
    }

    protected function appJson(JobApplication $a, bool $full = false): array
    {
        $out = [
            'id' => $a->id, 'number' => $a->number, 'name' => $a->name, 'position' => $a->position, 'experience' => $a->experience,
            'status' => $a->status, 'status_label' => trans('codeit_careers::app.statuses.'.$a->status),
            'email' => $a->email, 'phone' => trim($a->country_code.' '.$a->phone), 'whatsapp' => $a->whatsapp,
            'created_at' => self::iso($a->created_at),
        ];
        if ($full) {
            $out += [
                'portfolio_url' => $a->portfolio_url, 'notes' => (string) $a->notes,
                'answers' => collect($a->answers ?? [])->map(fn ($v, $k) => ['key' => (string) $k, 'value' => is_array($v) ? implode('، ', $v) : (string) $v])->values(),
                'files' => $a->files->map(fn ($f) => ['id' => $f->id, 'kind' => $f->kind, 'name' => $f->name, 'mime' => $f->mime, 'size' => (int) $f->size,
                    'url' => url('api/mobile/v1/careers/'.$a->id.'/files/'.$f->id)])->values(),
                'can_hire' => \Illuminate\Support\Facades\Route::has('admin.codeit.hr.hire') && \CodeIt\Mobile\Support\RouteGate::can('admin.codeit.hr.store'),
            ];
        }

        return $out;
    }
}
