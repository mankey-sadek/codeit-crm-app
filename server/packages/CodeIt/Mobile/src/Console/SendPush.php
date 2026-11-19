<?php

namespace CodeIt\Mobile\Console;

use CodeIt\Mobile\Support\Push;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class SendPush extends Command
{
    protected $signature = 'codeit:mobile-push';

    protected $description = 'code it app: push new bell notifications and chat messages to phones';

    public function handle(): int
    {
        if (! Push::enabled()) {
            return self::SUCCESS;
        }
        $state = fn ($k) => (int) Cache::get('codeit-mobile-push-'.$k, 0);
        $save = fn ($k, $v) => Cache::forever('codeit-mobile-push-'.$k, (int) $v);

        // first run: start from now, do not push history
        $lastN = $state('notif') ?: (int) DB::table('notifications')->max('id');
        foreach (DB::table('notifications')->where('id', '>', $lastN)->orderBy('id')->limit(200)->get() as $n) {
            Push::toUsers([(int) $n->user_id], (string) $n->title, (string) $n->description, [
                'kind' => 'notice', 'id' => $n->id, 'route' => (string) $n->route, 'entity' => (string) $n->entity_type, 'entity_id' => (string) $n->entity_id,
            ]);
            $lastN = $n->id;
        }
        $save('notif', $lastN);

        if (Schema::hasTable('codeit_chat_messages')) {
            $lastC = $state('chat') ?: (int) DB::table('codeit_chat_messages')->max('id');
            $msgs = DB::table('codeit_chat_messages as m')->leftJoin('users as u', 'u.id', '=', 'm.user_id')
                ->leftJoin('codeit_chat_conversations as c', 'c.id', '=', 'm.conversation_id')
                ->where('m.id', '>', $lastC)->whereNull('m.deleted_at')->orderBy('m.id')->limit(300)
                ->get(['m.id', 'm.conversation_id', 'm.user_id', 'm.kind', 'm.body', 'm.file_name', 'u.name as sender', 'c.title as title', 'c.type as type']);
            foreach ($msgs as $m) {
                $to = DB::table('codeit_chat_members')->where('conversation_id', $m->conversation_id)
                    ->where('user_id', '!=', (int) $m->user_id)->pluck('user_id')->map(fn ($v) => (int) $v)->all();
                $title = $m->type === 'group' && $m->title ? $m->title.' · '.$m->sender : (string) $m->sender;
                $body = $m->kind === 'text' ? (string) $m->body : '📎 '.($m->file_name ?: 'ملف');
                Push::toUsers($to, $title, $body, ['kind' => 'chat', 'conversation_id' => $m->conversation_id, 'channel' => 'chat']);
                $lastC = $m->id;
            }
            $save('chat', $lastC);
        }

        return self::SUCCESS;
    }
}
