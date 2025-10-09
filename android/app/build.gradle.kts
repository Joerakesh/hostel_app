// android/app/build.gradle (module)
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    // Apply the google services plugin for this module:
    id("com.google.gms.google-services")
}
android {
    namespace = "com.example.hostel_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.hostel_app"
        // ensure this value resolves to 21 or greater
        minSdk = flutter.minSdkVersion // <-- set to 21 if flutter.minSdkVersion is lower/undefined
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Use Firebase BoM to manage Firebase library versions
    implementation(platform("com.google.firebase:firebase-bom:34.3.0"))

    // Firebase Messaging (no version when using BoM)
    implementation("com.google.firebase:firebase-messaging")

    // Optional default analytics if you want
    implementation("com.google.firebase:firebase-analytics")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // other dependencies your app needs...
}