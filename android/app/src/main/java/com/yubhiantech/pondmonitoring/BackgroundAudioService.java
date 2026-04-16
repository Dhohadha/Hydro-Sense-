package com.yubhiantech.pondmonitoring;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import android.content.pm.ServiceInfo;
import android.os.Handler;
import android.app.AlarmManager;

public class BackgroundAudioService extends Service {
    private static final String TAG = "BackgroundAudioService";
    private static final String CHANNEL_ID = "alarm_channel";
    private static final String ACTION_STOP = "com.yubhiantech.pondmonitoring.ACTION_STOP_ALARM";
    private static final String PREF_ALARM_PLAYING = "alarm_playing";
    private static final String FLUTTER_PREFS = "FlutterSharedPreferences";
    private MediaPlayer mediaPlayer;
    private final Handler handler = new Handler();
    private String currentAudioPath;

    private final Runnable autoStopAndRestart = new Runnable() {
        @Override
        public void run() {
            Log.d(TAG, "5 minutes reached without stop. Pausing for 1 minute cycle.");
            stopAndScheduleRestart();
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "Background Audio Service Created");
        createAlarmNotificationChannel();
    }

    private void createAlarmNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "Critical Alerts",
                    NotificationManager.IMPORTANCE_HIGH
            );
            channel.setSound(
                    Uri.parse("android.resource://" + getPackageName() + "/raw/alarm"),
                    new AudioAttributes.Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .build()
            );
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) manager.createNotificationChannel(channel);
        }
    }

    private Notification buildForegroundNotification(String title) {
        Intent intent = new Intent(this, MainActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent content = PendingIntent.getActivity(
                this,
                0,
                intent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
        );

        Intent stopIntent = new Intent(this, BackgroundAudioService.class);
        stopIntent.setAction(ACTION_STOP);
        PendingIntent stopPi = PendingIntent.getService(
                this,
                1,
                stopIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
        );

        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("⚠️ " + title)
                .setContentText("Alarm ringing! Swipe down to see STOP ALARM button.")
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setStyle(new NotificationCompat.BigTextStyle().bigText("Continuous alarm is playing in the background. Swipe down to reveal the STOP ALARM button to silence it."))
                .addAction(android.R.drawable.ic_delete, "STOP ALARM", stopPi)
                .setContentIntent(content)
                .build();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            Log.d(TAG, "Stop Action received. Cancelling cycle.");
            cancelRestartSchedule();
            markAlarmPlaying(false);
            stopSelf();
            return START_NOT_STICKY;
        }

        currentAudioPath = intent != null ? intent.getStringExtra("audioPath") : null;
        try {
            Notification n = buildForegroundNotification("Aerator Alert");
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(1001, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
            } else {
                startForeground(1001, n);
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to start foreground: " + e.getMessage());
        }

        try {
            if (mediaPlayer != null) {
                mediaPlayer.stop();
                mediaPlayer.release();
                mediaPlayer = null;
            }

            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build();

            if (currentAudioPath != null && !currentAudioPath.isEmpty()) {
                mediaPlayer = new MediaPlayer();
                mediaPlayer.setAudioAttributes(attrs);
                mediaPlayer.setDataSource(currentAudioPath);
                mediaPlayer.setLooping(true);
                mediaPlayer.prepare();
                mediaPlayer.start();
                Log.d(TAG, "Started playing audio from file (Alarm Stream): " + currentAudioPath);
            } else {
                mediaPlayer = MediaPlayer.create(this, R.raw.alarm);
                if (mediaPlayer != null) {
                    mediaPlayer.setAudioAttributes(attrs);
                    mediaPlayer.setLooping(true);
                    mediaPlayer.start();
                    Log.d(TAG, "Started playing audio from raw resource (Alarm Stream)");
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error starting media playback: " + e.getMessage());
        }

        // Remove the 5-minute auto-stop timer so it runs indefinitely
        handler.removeCallbacks(autoStopAndRestart);

        markAlarmPlaying(true);
        return START_STICKY;
    }

    private void stopAndScheduleRestart() {
        if (mediaPlayer != null) {
            mediaPlayer.stop();
            mediaPlayer.release();
            mediaPlayer = null;
        }

        // Schedule restart after 1 minute
        Intent restartIntent = new Intent(this, BackgroundAudioService.class);
        restartIntent.putExtra("audioPath", currentAudioPath);
        
        PendingIntent pi = PendingIntent.getService(
                this,
                101,
                restartIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
        );

        AlarmManager am = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        if (am != null) {
            long triggerAt = System.currentTimeMillis() + (60 * 1000); // 1 minute
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi);
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi);
            }
        }
        
        markAlarmPlaying(false); // Flag false during the 1-minute pause
        stopSelf();
    }

    private void cancelRestartSchedule() {
        handler.removeCallbacks(autoStopAndRestart);
        
        Intent restartIntent = new Intent(this, BackgroundAudioService.class);
        PendingIntent pi = PendingIntent.getService(
                this,
                101,
                restartIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_NO_CREATE : PendingIntent.FLAG_NO_CREATE
        );
        
        if (pi != null) {
            AlarmManager am = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
            if (am != null) am.cancel(pi);
            pi.cancel();
        }
    }

    private void markAlarmPlaying(boolean playing) {
        // Update native default prefs (not used by Flutter but kept for completeness)
        SharedPreferences prefs = getSharedPreferences(getPackageName() + "_preferences", Context.MODE_PRIVATE);
        prefs.edit().putBoolean(PREF_ALARM_PLAYING, playing).apply();

        // Also update Flutter SharedPreferences so Dart sees consistent state
        SharedPreferences flutterPrefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE);
        flutterPrefs.edit().putBoolean("flutter." + PREF_ALARM_PLAYING, playing).apply();
        if (playing) {
            flutterPrefs.edit().putString("flutter.last_alarm_trigger", String.valueOf(System.currentTimeMillis())).apply();
        }
    }

    @Override
    public void onDestroy() {
        cancelRestartSchedule();
        if (mediaPlayer != null) {
            mediaPlayer.stop();
            mediaPlayer.release();
            mediaPlayer = null;
        }
        markAlarmPlaying(false);
        Log.d(TAG, "Background Audio Service Destroyed");
        super.onDestroy();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) { return null; }
}