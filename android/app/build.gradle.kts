// 1. IMPORT PROPERTIES (Required to read the file)
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 2. LOAD LOCAL.PROPERTIES
// This block reads the file where you hid the secret key
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

android {
    namespace = "com.example.student_card_scanner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.student_card_scanner"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 3. INJECT THE SECRET
        // This takes the key from local.properties and creates a Java variable "APP_CENTER_SECRET"
        val appCenterSecret = localProperties.getProperty("app.center.secret")
        if (appCenterSecret != null) {
            buildConfigField("String", "APP_CENTER_SECRET", appCenterSecret)
        }
    }

    buildFeatures {
        // 4. ENABLE BUILD CONFIG
        // This allows the app to generate the 'BuildConfig' class
        buildConfig = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

repositories {
    flatDir {
        dirs("libs")
    }
}

dependencies {
    val room_version = "2.6.1"
    implementation("androidx.room:room-runtime:$room_version")

    // Ensure the filename in 'libs' matches this exactly (e.g., card-emulator-debug.aar)
    implementation(mapOf("name" to "card-emulator-debug", "ext" to "aar"))

    val appCenterSdkVersion = "5.0.4"
    implementation("com.microsoft.appcenter:appcenter-analytics:$appCenterSdkVersion")
    implementation("com.microsoft.appcenter:appcenter-crashes:$appCenterSdkVersion")
}

flutter {
    source = "../.."
}