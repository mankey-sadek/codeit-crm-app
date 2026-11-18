<?php

namespace CodeIt\Mobile\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Routing\Controller as Base;
use Illuminate\Support\Facades\Cache;
use Webkul\User\Models\User;

/** Opens a one-time link from the app: signs the person in to the web CRM and goes to the page. */
class WebHandoffController extends Base
{
    public function __invoke(string $code): RedirectResponse
    {
        $data = Cache::pull('codeit-mobile-web|'.hash('sha256', $code));
        $user = $data ? User::find($data['user']) : null;
        if (! $user || ! (int) $user->status) {
            return redirect('/admin/login');
        }
        auth()->guard('user')->login($user);
        request()->session()->regenerate();

        return redirect($data['to']);
    }
}
