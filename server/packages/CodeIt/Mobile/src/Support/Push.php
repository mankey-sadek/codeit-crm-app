<?php

namespace CodeIt\Mobile\Support;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

/**
 * Push to the code it CRM app through Firebase Cloud Messaging (HTTP v1, one service account JSON,
 * no extra packages). Every minute the scheduler sends what is new since last time:
 *  - the CRM bell (notifications table: HR, tasks, tickets, mail ...)
 *  - team chat messages, to the other members of the conversation.
 */
class Push
{
    public static function listen(): void
    {
        app()->booted(function () {
            if (app()->runningInConsole()) {
                app(Schedule::class)->command('codeit:mobile-push')->everyMinute()->withoutOverlapping(5);
            }
        });
    }

    public static function enabled(): bool
    {
        $f = (string) config('codeit_mobile.fcm_credentials');

        return $f !== '' && is_readable($f) && Schema::hasTable('codeit_mobile_devices');
    }

    /** @return array{sent:int, failed:int} */
    public static function toUsers(array $userIds, string $title, string $body, array $data = []): array
    {
        $sent = $failed = 0;
        if (! static::enabled() || ! $userIds) {
            return compact('sent', 'failed');
        }
        $creds = json_decode((string) file_get_contents(config('codeit_mobile.fcm_credentials')), true);
        $token = static::accessToken($creds);
        if (! $token) {
            return compact('sent', 'failed');
        }
        $url = 'https://fcm.googleapis.com/v1/projects/'.$creds['project_id'].'/messages:send';
        $devices = DB::table('codeit_mobile_devices')->whereIn('user_id', array_unique($userIds))->get();
        foreach ($devices as $d) {
            $unread = (int) DB::table('notifications')->where('user_id', $d->user_id)->where('is_read', 0)->count();
            $msg = [
                'token' => $d->push_token,
                'notification' => ['title' => mb_strimwidth($title, 0, 120, '…'), 'body' => mb_strimwidth($body, 0, 240, '…')],
                'data' => array_map('strval', $data),
                'android' => ['priority' => 'high', 'notification' => ['channel_id' => $data['channel'] ?? 'crm', 'color' => '#2BFF88', 'icon' => 'ic_stat_codeit']],
                'apns' => ['payload' => ['aps' => ['sound' => 'default', 'badge' => $unread]]],
            ];
            $res = Http::withToken($token)->timeout(10)->post($url, ['message' => $msg]);
            if ($res->successful()) {
                $sent++;
            } else {
                $failed++;
                $code = $res->json('error.details.0.errorCode') ?? $res->json('error.status');
                if (in_array($code, ['UNREGISTERED', 'INVALID_ARGUMENT', 'NOT_FOUND'], true)) {
                    DB::table('codeit_mobile_devices')->where('id', $d->id)->delete();
                } else {
                    Log::warning('codeit mobile push failed: '.$res->status().' '.mb_substr($res->body(), 0, 300));
                }
            }
        }

        return compact('sent', 'failed');
    }

    protected static function accessToken(array $c): ?string
    {
        return Cache::remember('codeit-fcm-token', 3000, function () use ($c) {
            $now = time();
            $b64 = fn ($s) => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
            $head = $b64(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $claim = $b64(json_encode([
                'iss' => $c['client_email'], 'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token', 'iat' => $now, 'exp' => $now + 3600,
            ]));
            $sig = '';
            if (! openssl_sign($head.'.'.$claim, $sig, $c['private_key'], 'sha256WithRSAEncryption')) {
                Log::warning('codeit mobile push: bad private key in the service account file');

                return null;
            }
            $res = Http::asForm()->timeout(10)->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $head.'.'.$claim.'.'.$b64($sig),
            ]);

            return $res->json('access_token');
        });
    }
}
