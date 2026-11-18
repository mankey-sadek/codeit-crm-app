<?php

use CodeIt\Mobile\Http\Controllers\AuthController;
use CodeIt\Mobile\Http\Controllers\CareersController;
use CodeIt\Mobile\Http\Controllers\ChatController;
use CodeIt\Mobile\Http\Controllers\HomeController;
use CodeIt\Mobile\Http\Controllers\HrController;
use CodeIt\Mobile\Http\Controllers\MailController;
use CodeIt\Mobile\Http\Controllers\SalesController;
use CodeIt\Mobile\Http\Controllers\WorkController;
use CodeIt\Mobile\Http\Middleware\MobileAuth;
use Illuminate\Support\Facades\Route;

// /api/mobile/v1/...
Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:codeit-mobile-login');

Route::middleware([MobileAuth::class, 'throttle:codeit-mobile'])->group(function () {
    Route::get('me', [AuthController::class, 'me']);
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::post('devices', [AuthController::class, 'device']);

    Route::controller(HomeController::class)->group(function () {
        Route::get('home', 'home');
        Route::get('search', 'search');
        Route::get('notifications', 'notifications');
        Route::post('notifications/read-all', 'readAllNotifications');
        Route::post('notifications/{id}/read', 'readNotification')->whereNumber('id');
    });

    Route::controller(SalesController::class)->group(function () {
        Route::get('pipelines', 'pipelines');
        Route::get('leads', 'leads');
        Route::get('leads/board', 'board');
        Route::get('leads/{id}', 'lead')->whereNumber('id');
        Route::post('leads/{id}/stage', 'leadStage')->whereNumber('id');
        Route::get('persons', 'persons');
        Route::get('persons/{id}', 'person')->whereNumber('id');
        Route::get('organizations', 'organizations');
        Route::get('organizations/{id}', 'organization')->whereNumber('id');
        Route::get('activities', 'activities');
        Route::post('activities', 'storeActivity');
        Route::put('activities/{id}', 'updateActivity')->whereNumber('id');
        Route::get('quotes', 'quotes');
        Route::get('quotes/{id}', 'quote')->whereNumber('id');
        Route::get('products', 'products');
    });

    Route::controller(MailController::class)->group(function () {
        Route::get('mail/attachments/{id}', 'attachment')->whereNumber('id');
        Route::post('mail', 'send');
        Route::get('mail/{folder}', 'index')->where('folder', 'inbox|sent|draft|outbox|trash');
        Route::get('mail/{folder}/{id}', 'show')->where('folder', 'inbox|sent|draft|outbox|trash')->whereNumber('id');
    });

    Route::controller(WorkController::class)->group(function () {
        Route::get('projects', 'projects');
        Route::get('projects/{id}', 'project')->whereNumber('id');
        Route::post('projects/{id}/tasks', 'storeProjectTask')->whereNumber('id');
        Route::put('project-tasks/{taskId}', 'updateProjectTask')->whereNumber('taskId');

        Route::get('tasks', 'tasks');
        Route::post('tasks', 'storeTask');
        Route::get('tasks/{id}', 'task')->whereNumber('id');
        Route::post('tasks/{id}/status', 'taskStatus')->whereNumber('id');
        Route::post('tasks/{id}/comment', 'taskComment')->whereNumber('id');
        Route::post('tasks/{id}/files', 'taskFiles')->whereNumber('id');
        Route::get('task-files/{fileId}', 'teamFile')->whereNumber('fileId');

        Route::get('tickets', 'tickets');
        Route::get('tickets/{id}', 'ticket')->whereNumber('id');
        Route::post('tickets/{id}/reply', 'ticketReply')->whereNumber('id');
        Route::put('tickets/{id}', 'ticketUpdate')->whereNumber('id');
        Route::post('tickets/{id}/hours', 'ticketHours')->whereNumber('id');
        Route::get('ticket-files/{attachmentId}', 'ticketFile')->whereNumber('attachmentId');

        Route::get('invoices', 'invoices');
        Route::get('invoices/{id}', 'invoice')->whereNumber('id');
        Route::post('invoices/{id}/payments', 'invoicePayment')->whereNumber('id');
    });

    Route::controller(ChatController::class)->prefix('chat')->group(function () {
        Route::get('', 'index');
        Route::get('users', 'users');
        Route::post('conversations', 'open');
        Route::get('{id}/messages', 'messages')->whereNumber('id');
        Route::post('{id}/messages', 'send')->whereNumber('id')->middleware('throttle:codeit-chat-send');
        Route::get('{id}/files/{messageId}', 'file')->whereNumber(['id', 'messageId']);
    });

    Route::controller(HrController::class)->prefix('hr')->group(function () {
        Route::get('me', 'me');
        Route::post('punch', 'punch');
        Route::get('employees', 'employees');
        Route::get('employees/{id}', 'employee')->whereNumber('id');
        Route::get('attendance', 'attendance');
        Route::post('attendance', 'saveAttendance');
        Route::get('leaves', 'leaves');
        Route::post('leaves', 'storeLeave');
        Route::post('leaves/{id}/decide', 'decideLeave')->whereNumber('id');
        Route::post('leaves/{id}/cancel', 'cancelLeave')->whereNumber('id');
        Route::get('payroll', 'payroll');
        Route::post('payroll/{action}', 'payrollAction')->where('action', 'refresh|approve|paid');
        Route::get('payslips/{id}', 'payslip')->whereNumber('id');
    });

    Route::controller(CareersController::class)->prefix('careers')->group(function () {
        Route::get('', 'index');
        Route::get('{id}', 'show')->whereNumber('id');
        Route::put('{id}', 'update')->whereNumber('id');
        Route::get('{id}/files/{fileId}', 'file')->whereNumber(['id', 'fileId']);
    });
});
