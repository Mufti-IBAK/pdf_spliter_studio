plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.slicepdf.studio.pdf_spliter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.slicepdf.studio.pdf_spliter"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 11
        versionName = "1.0.2"
    }

    signingConfigs {
        create("release") {
            val keystoreFile = file("plexus_release.jks")
            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = "plexus2026"
                keyAlias = "plexus_key"
                keyPassword = "plexus2026"
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    // Compress native .so libraries inside the APK to reduce APK file size by ~50%
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            signingConfig = if (file("plexus_release.jks").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
