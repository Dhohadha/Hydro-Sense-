# Flutter essential rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.firebase_messaging.** { *; }

# MQTT (mqtt_client)
-keep class org.eclipse.paho.client.mqttv3.** { *; }

# AudioPlayers
-keep class com.ryanheise.audioservice.** { *; }

# Prevent shrinking of important assets
-keepclassmembers class * extends android.app.Activity {
   public void *(android.view.View);
}
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.content.ContentProvider
