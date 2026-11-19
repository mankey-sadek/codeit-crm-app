package com.coditvision.codeit_crm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // push channels the CRM sends to ("crm" = the bell, "chat" = team chat)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel("crm", "إشعارات الـ CRM", NotificationManager.IMPORTANCE_HIGH))
            nm.createNotificationChannel(NotificationChannel("chat", "شات الفريق", NotificationManager.IMPORTANCE_HIGH))
        }
    }
}
