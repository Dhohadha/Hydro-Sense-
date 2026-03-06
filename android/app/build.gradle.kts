plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.yubhiantech.pondmonitoring"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8

        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

     signingConfigs {
        create("release") {
            storeFile = file("D:/flutterr/pond-monitoring-system-new-dev/satya_release.jks")
            storePassword = "Satya123456"
            keyAlias = "my-key-alias"
            keyPassword = "Satya123456"
        }
        getByName("debug") {
            storeFile = file("D:/flutterr/pond-monitoring-system-new-dev/satya_release.jks")
            storePassword = "Satya123456"
            keyAlias = "my-key-alias"
            keyPassword = "Satya123456"
        }
    }
    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yubhiantech.pondmonitoring"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true  // Enable code shrinking
            isShrinkResources = true  // Remove unused resources
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    // Don’t use $kotlin_version in Kotlin DSL. Use explicit version:
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.24")
    implementation("androidx.core:core-ktx:1.13.1")
    // Required for Flutter embedding's PlayStoreDeferredComponentManager (fix R8 missing classes)
    implementation("com.google.android.play:core:1.10.3")

    // 🔥 Required for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
