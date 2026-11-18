<?php

namespace CodeIt\Mobile\Support;

use Webkul\Admin\Http\Middleware\Bouncer;

/** The CRM's own route permission check (role ACL), for a route name we call from the app. */
class RouteGate extends Bouncer
{
    public function authorizeRoute(string $routeName): void
    {
        $user = auth()->guard('user')->user();
        abort_unless($user && $user->role, 401);
        if ($user->role->permission_type === 'all') {
            return;
        }
        $roles = acl()->getRoles();
        if (isset($roles[$routeName])) {
            abort_unless(bouncer()->hasPermission($roles[$routeName]), 403);

            return;
        }
        if ($this->isAllowlistedRoute($routeName)) {
            return;
        }
        abort_unless($this->isAuthorizedByFeature($routeName, $roles), 403);
    }

    public static function can(string $routeName): bool
    {
        try {
            (new static)->authorizeRoute($routeName);

            return true;
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException) {
            return false;
        }
    }
}
