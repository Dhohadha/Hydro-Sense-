package com.yubhiantech.pondmonitoring

import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yubhiantech.pondmonitoring/alarm"
    private val NOTIF_CHANNEL_ID = "alarm_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Register plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarm" -> {
                    startAlarmService()
                    result.success(true)
                }
                "stopAlarm" -> {
                    stopAlarmService()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createAlarmNotificationChannel()
    }

    private fun createAlarmNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java) ?: return
            val existing = manager.getNotificationChannel(NOTIF_CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    "Critical Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                )
                val soundUri = Uri.parse("android.resource://" + packageName + "/raw/alarm")
                channel.setSound(
                    soundUri,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                manager.createNotificationChannel(channel)
            }
        }
    }

    private fun startAlarmService() {
    // Create an intent to start the background audio service (will use raw resource fallback)
    val intent = Intent(this, BackgroundAudioService::class.java)

        // Start the service as a foreground service for Android O+
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            // Fallback
            startService(intent)
        }
    }

    private fun stopAlarmService() {
        // Create an intent to stop the background audio service
        val intent = Intent(this, BackgroundAudioService::class.java)
        stopService(intent)
    }
}
