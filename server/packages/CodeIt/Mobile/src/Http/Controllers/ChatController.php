<?php

namespace CodeIt\Mobile\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

/** Team chat: the chat module's own JSON endpoints, plus names so the app can draw the list. */
class ChatController extends Controller
{
    public function index(): JsonResponse
    {
        $d = $this->page('admin.codeit.chat.sync', [], array_filter([
            'conversation' => request('conversation'), 'after' => request('after'), 'seen' => request('seen'), 'from' => request('from'),
        ]));
        $me = $this->user()->id;
        $names = DB::table('users')->pluck('name', 'id');
        $d['conversations'] = collect($d['conversations'] ?? [])->map(function ($c) use ($names, $me) {
            $other = collect($c['members'] ?? [])->first(fn ($u) => (int) $u !== $me);
            $c['name'] = $c['type'] === 'group' ? ($c['title'] ?: 'جروب') : ($names[$other] ?? 'محادثة');
            $c['other_id'] = $c['type'] === 'group' ? null : $other;
            if (isset($c['last']['user_id'])) {
                $c['last']['sender'] = $names[$c['last']['user_id']] ?? '';
            }

            return $c;
        })->values();
        $d['me'] = $me;
        $d['names'] = $names;
        if (isset($d['messages'])) {
            $d['messages'] = collect($d['messages'])->map(fn ($m) => $this->msg($m, (int) request('conversation'), $names))->values();
        }

        return response()->json($d);
    }

    public function messages(int $id): JsonResponse
    {
        $d = $this->page('admin.codeit.chat.messages', ['id' => $id], array_filter(['before' => request('before')]));
        $names = DB::table('users')->pluck('name', 'id');
        $d['messages'] = collect($d['messages'] ?? [])->map(fn ($m) => $this->msg($m, $id, $names))->values();

        return response()->json($d);
    }

    public function send(int $id): JsonResponse
    {
        $res = $this->run('admin.codeit.chat.send', ['id' => $id], request()->only(['body']));
        $d = $res->getData(true);
        if (isset($d['message']) && is_array($d['message'])) {
            $d['message'] = $this->msg($d['message'], $id, DB::table('users')->pluck('name', 'id'));
        }

        return response()->json($d, $res->getStatusCode());
    }

    public function open(): JsonResponse
    {
        return $this->run('admin.codeit.chat.open', [], request()->only(['type', 'user_id', 'user_ids', 'title']));
    }

    public function users(): JsonResponse
    {
        return $this->run('admin.codeit.chat.users', [], []);
    }

    public function file(int $id, int $messageId)
    {
        return $this->run('admin.codeit.chat.file', ['id' => $id, 'messageId' => $messageId], []);
    }

    protected function msg(array $m, int $conversation, $names): array
    {
        $m['sender'] = $names[$m['user_id'] ?? 0] ?? '';
        $m['mine'] = (int) ($m['user_id'] ?? 0) === $this->user()->id;
        if (! empty($m['file']) && is_array($m['file'])) {
            $m['file']['url'] = url('api/mobile/v1/chat/'.$conversation.'/files/'.$m['id']);
        }

        return $m;
    }
}
