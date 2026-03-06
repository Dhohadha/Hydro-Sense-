# ProGuard / R8 rules for Flutter + Firebase stack
# Keep Flutter embedding and plugin registrant
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep Activity, Service, Receiver, Provider (Android components)
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Firebase common
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Play Core / SplitInstall (referenced by Flutter embedding for deferred components)
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**

# Kotlin coroutines metadata
-keepclassmembers class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Retrofit/OkHttp (if used transitively)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Gson/Moshi reflection (if present transitively)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep Dart/Flutter assets lookup via reflection
-keep class io.flutter.view.FlutterMain { *; }

# Keep audioplayers' platform channels if proguarded (defensive)
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# Avoid stripping annotations
-keepattributes *Annotation*

# Keep enums' values() and valueOf()
-keepclassmembers enum * { *; }

# Keep kotlin metadata
-keepclassmembers class kotlin.Metadata { *; }

# R8 optimization tweaks (safe defaults)
-dontnote **
