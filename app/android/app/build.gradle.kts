import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured via `android/key.properties` (kept out of
// version control). When that file is absent — CI, a fresh clone, or
// `flutter run --release` without the keystore — the release build falls back
// to debug signing so it still succeeds. The real keystore is upgrade-critical:
// it must be backed up and reused for every release, or in-place updates break
// and users lose their data (#24, #19).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.golfy.golfy_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent. Once a build is uploaded to Google Play, even to internal
        // testing, this id belongs to that developer account for good, and it
        // is also the key to every installed copy's database: a new id is a new
        // app that cannot see the old one's data (#23, #24, #74, #138).
        applicationId = "com.golfy.golfy_app"
        // Pinned rather than inherited from the Flutter SDK, so a Flutter upgrade
        // can't move them silently (#74). Google Play requires new apps and
        // updates to target API 36 from 2026-08-31; the floor rises every
        // August, so raise targetSdk before then, after reading that Android
        // version's behaviour changes. Re-check both whenever the pinned Flutter
        // SDK moves, in case Flutter raises its own minimum above minSdk.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Default launcher label; the debug build type overrides it below.
        // Only the label is "Golfy": applicationId and namespace stay
        // com.golfy.golfy_app, since changing them would orphan installed data (#138).
        manifestPlaceholders["appLabel"] = "Golfy"
    }

    signingConfigs {
        create("release") {
            // Populated from key.properties when present; left empty otherwise
            // (the release build type falls back to debug signing below).
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Sign with the real release keystore when configured (key.properties),
            // otherwise fall back to debug signing so CI and `flutter run --release`
            // keep working without the secret keystore.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        debug {
            // Give debug / `flutter run` builds their own application ID so dev
            // data sandboxes to a separate app-private database and the debug
            // build can coexist with a real release install on one device (#23).
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            manifestPlaceholders["appLabel"] = "Golfy (debug)"
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
