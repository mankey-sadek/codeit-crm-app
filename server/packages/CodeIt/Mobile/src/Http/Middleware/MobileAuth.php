<?php

namespace CodeIt\Mobile\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;
use Webkul\User\Models\User;

/**
 * "Authorization: Bearer <token>" from /auth/login. Logs the token's user into the CRM's "user"
 * guard for this request only, so bouncer(), Hr::me() and the module controllers see them.
 */
class MobileAuth
{
    public function handle(Request $request, Closure $next): Response
    {
        $plain = (string) $request->bearerToken();
        $token = $plain !== '' ? PersonalAccessToken::findToken($plain) : null;
        $days = (int) config('codeit_mobile.token_days', 60);

        if (! $token || ! $token->tokenable instanceof User || $token->name !== 'codeit-mobile'
            || ($token->expires_at && $token->expires_at->isPast())
            || ($token->last_used_at ?? $token->created_at)->lt(now()->subDays($days))) {
            abort(401);
        }

        /** @var User $user */
        $user = $token->tokenable;
        if (! (int) $user->status || ! $user->role || ($user->role->permission_type !== 'all' && empty($user->role->permissions))) {
            $token->delete();
            abort(401);
        }

        if (! $token->last_used_at || $token->last_used_at->lt(now()->subMinutes(5))) {
            $token->forceFill(['last_used_at' => now()])->save();
        }

        auth()->guard('user')->setUser($user);
        auth()->shouldUse('user');
        $request->setUserResolver(fn () => $user);
        $request->attributes->set('ci_user_id', $user->id);
        $request->attributes->set('ci_token', $token);

        return $next($request);
    }
}
