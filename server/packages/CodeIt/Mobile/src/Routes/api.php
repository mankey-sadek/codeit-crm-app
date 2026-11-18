<?php

use CodeIt\Mobile\Http\Controllers\AuthController;
use CodeIt\Mobile\Http\Middleware\MobileAuth;
use Illuminate\Support\Facades\Route;

Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:codeit-mobile-login');

Route::middleware([MobileAuth::class, 'throttle:codeit-mobile'])->group(function () {
    Route::get('me', [AuthController::class, 'me']);
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::post('devices', [AuthController::class, 'device']);
});
