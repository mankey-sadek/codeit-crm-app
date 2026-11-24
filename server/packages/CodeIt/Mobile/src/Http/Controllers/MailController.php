<?php

namespace CodeIt\Mobile\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Webkul\Email\Models\Email;

/** The CRM mailbox (inbox / sent / draft / trash), with the same folder permissions as the web. */
class MailController extends Controller
{
    protected const FOLDERS = ['inbox', 'sent', 'draft', 'outbox', 'trash'];

    public function index(string $folder = 'inbox'): JsonResponse
    {
        abort_unless(in_array($folder, self::FOLDERS, true), 404);
        $g = $this->grid('admin.mail.index', ['route' => $folder], [], ['column' => 'created_at', 'order' => 'desc']);
        $rows = self::ordered(Email::class, $g['ids'], ['attachments']);

        return response()->json(['data' => $rows->map(fn ($e) => $this->mailJson($e, $folder))->values(), 'meta' => $g['meta']]);
    }

    public function show(string $folder, int $id): JsonResponse
    {
        $e = $this->page('admin.mail.view', ['route' => $folder, 'id' => $id])['email'] ?? null;
        abort_unless($e, 404);
        if (! $e->is_read) {
            $e->forceFill(['is_read' => 1])->saveQuietly();
        }

        return response()->json(['data' => $this->mailJson($e, $folder, true) + [
            'thread' => $e->emails->map(fn ($r) => $this->mailJson($r, $folder, true))->values(),
            'lead' => self::ref($e->lead, 'title'),
            'person' => self::ref($e->person),
        ]]);
    }

    /** Reply (or a new mail): to, subject, body; sends from the CRM's mailbox like the web. */
    public function send(): JsonResponse
    {
        $d = request()->validate([
            'to' => ['required', 'array', 'min:1'], 'to.*' => ['email'],
            'cc' => ['nullable', 'array'], 'cc.*' => ['email'],
            'subject' => ['required', 'string', 'max:250'],
            'body' => ['required', 'string', 'max:50000'],
            'parent_id' => ['nullable', 'integer'],
            'lead_id' => ['nullable', 'integer'],
            'person_id' => ['nullable', 'integer'],
        ]);
        $html = nl2br(e($d['body']));

        return $this->act('admin.mail.store', [], array_filter([
            'reply_to' => $d['to'], 'cc' => $d['cc'] ?? null, 'subject' => $d['subject'], 'reply' => $html,
            'parent_id' => $d['parent_id'] ?? null, 'lead_id' => $d['lead_id'] ?? null, 'person_id' => $d['person_id'] ?? null,
        ], fn ($v) => $v !== null));
    }

    public function attachment(int $id)
    {
        return $this->run('admin.mail.attachment_download', ['id' => $id], []);
    }

    protected function mailJson(Email $e, string $folder, bool $full = false): array
    {
        $from = is_array($e->from) ? implode(', ', $e->from) : (string) $e->from;
        $out = [
            'id' => $e->id,
            'subject' => (string) $e->subject,
            'from' => $e->name ? $e->name.' <'.$from.'>' : $from,
            'to' => array_values((array) $e->reply_to),
            'snippet' => mb_strimwidth(self::plain($e->reply), 0, 160, '…'),
            'is_read' => (bool) $e->is_read,
            'folder' => $folder,
            'created_at' => self::iso($e->created_at),
            'attachments' => $e->attachments->map(fn ($a) => [
                'id' => $a->id, 'name' => $a->name, 'size' => (int) $a->size, 'mime' => (string) $a->content_type,
                'url' => url('api/mobile/v1/mail/attachments/'.$a->id),
            ])->values(),
        ];
        if ($full) {
            $out['body'] = self::plain(preg_replace('#<br\s*/?>|</p>|</div>#i', "\n", (string) $e->reply));
            $out['cc'] = array_values((array) $e->cc);
        }

        return $out;
    }
}
