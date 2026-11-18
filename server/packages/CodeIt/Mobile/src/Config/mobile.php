<?php

return [
    // Firebase Cloud Messaging (push to Android + iOS). Path of the service account JSON from
    // Firebase console > Project settings > Service accounts. Empty = no push, the app still works.
    'fcm_credentials' => env('CODEIT_FCM_CREDENTIALS', storage_path('app/private/codeit-fcm.json')),
    // login tokens live this many days without use before they stop working
    'token_days' => (int) env('CODEIT_MOBILE_TOKEN_DAYS', 60),
    // the lowest app build the server still accepts (to force an update after a breaking change)
    'min_build' => (int) env('CODEIT_MOBILE_MIN_BUILD', 1),
];
