pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

gradle.beforeProject {
    buildscript.configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin" &&
                (requested.name == "kotlin-gradle-plugin" ||
                    requested.name == "kotlin-compiler-embeddable" ||
                    requested.name == "kotlin-stdlib")
            ) {
                useVersion("2.4.0")
            }
            if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                useVersion("9.1.0")
            }
        }
    }
}

include(":app")
