<?php

namespace CodeIt\Mobile\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Every mobile call: JSON in and out, Arabic texts, and an in-memory session so the CRM's own
 * controllers (which flash "success" messages and redirect back) can run unchanged.
 */
class MobileJson
{
    public function handle(Request $request, Closure $next): Response
    {
        $request->headers->set('Accept', 'application/json');
        config(['session.driver' => 'array']);
        $session = app('session')->driver('array');
        $session->start();
        $request->setLaravelSession($session);
        app()->setLocale(in_array($request->header('X-Locale'), ['ar', 'en'], true) ? $request->header('X-Locale') : 'ar');

        $response = $next($request);
        $response->headers->set('Cache-Control', 'no-store');

        return $response;
    }
}
