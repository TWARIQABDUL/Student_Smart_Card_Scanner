import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. LOAD KEY & LOCAL PROPERTIES
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

android {
    namespace = "com.example.student_card_scanner"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.student_card_scanner"
        minSdk = 27
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 2. INJECT APP CENTER SECRET
        val appCenterSecret = localProperties.getProperty("app.center.secret")
        if (appCenterSecret != null) {
            buildConfigField("String", "APP_CENTER_SECRET", appCenterSecret)
        }
    }

    buildFeatures {
        buildConfig = true
    }

    // 3. DEFINE SIGNING CONFIG (For Release)
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            // 4. USE THE RELEASE KEY
            signingConfig = signingConfigs.getByName("release")
            var minifyEnabled = true
            var shrinkResources = true
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

    // 5. USE FILES SYNTAX (Fixes "Compilation not supported" error)
    // Make sure 'card-emulator-release.aar' is in 'android/app/libs/'
    implementation(files("libs/card-emulator-release.aar"))

    val appCenterSdkVersion = "5.0.4"
    implementation("com.microsoft.appcenter:appcenter-analytics:$appCenterSdkVersion")
    implementation("com.microsoft.appcenter:appcenter-crashes:$appCenterSdkVersion")
}

flutter {
    source = "../.."
}