<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('codeit_mobile_devices')) {
            return;
        }
        Schema::create('codeit_mobile_devices', function (Blueprint $t) {
            $t->id();
            $t->unsignedInteger('user_id')->index();
            $t->unsignedBigInteger('token_id')->nullable()->index();
            $t->string('push_token', 500);
            $t->string('platform', 10);
            $t->string('app_version', 40)->nullable();
            $t->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('codeit_mobile_devices');
    }
};
