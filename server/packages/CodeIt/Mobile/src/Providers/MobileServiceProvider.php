<?php

namespace CodeIt\Mobile\Providers;

use CodeIt\Mobile\Http\Middleware\MobileAuth;
use CodeIt\Mobile\Http\Middleware\MobileJson;
use CodeIt\Mobile\Support\Push;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

/**
 * code it mobile app API (/api/mobile/v1). Token login with the CRM's own users, and every screen
 * reads the same data the web pages get, with the same permissions (role ACL + HR/Team visibility).
 * Not in Laravel's "api" group on purpose: Sanctum would treat same-origin calls as stateful.
 */
class MobileServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->mergeConfigFrom(dirname(__DIR__).'/Config/mobile.php', 'codeit_mobile');
    }

    public function boot(): void
    {
        RateLimiter::for('codeit-mobile-login', fn (Request $r) => [
            Limit::perMinute(8)->by('mlogin|'.$r->ip()),
            Limit::perHour(30)->by('mlogin-mail|'.mb_strtolower((string) $r->input('email'))),
        ]);
        RateLimiter::for('codeit-mobile', fn (Request $r) => Limit::perMinute(240)->by('mobile|'.($r->attributes->get('ci_user_id') ?? $r->ip())));

        Route::prefix('api/mobile/v1')
            ->middleware([\CodeIt\Brand\Http\Middleware\ApiErrors::class, MobileJson::class, \Illuminate\Routing\Middleware\SubstituteBindings::class])
            ->group(dirname(__DIR__).'/Routes/api.php');

        // one-time link from the app to a web page (signed in as the same person)
        Route::middleware(['web', 'throttle:20,1'])->get('mobile-web/{code}', \CodeIt\Mobile\Http\Controllers\WebHandoffController::class)
            ->where('code', '[A-Za-z0-9]{48}');

        $this->loadMigrationsFrom(dirname(__DIR__).'/Database/Migrations');

        if ($this->app->runningInConsole()) {
            $this->commands([\CodeIt\Mobile\Console\SendPush::class]);
        }
        Push::listen();
    }
}
