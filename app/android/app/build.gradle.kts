import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured via `android/key.properties` (kept out of
// version control), which holds up to two keys:
//
// - the app-signing key (storeFile, keyAlias, …) signs the sideload APK. It is
//   upgrade-critical: it must be backed up and reused for every release, or
//   in-place updates break and users lose their data (#24, #19).
// - the upload key (uploadStoreFile, uploadKeyAlias, …) signs the App Bundle
//   for Google Play, which checks it and re-signs the app with the app-signing
//   key (Play App Signing, #74).
//
// A key that isn't configured — CI, a fresh clone, or `flutter run --release`
// without the keystore — falls back to debug signing so the build still
// succeeds.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasAppSigningKey = keystoreProperties.containsKey("storeFile")
val hasUploadKey = keystoreProperties.containsKey("uploadStoreFile")

// AGP gives an APK and a bundle of the same variant one signingConfig, so the
// tasks Gradle was asked to run are the only place the two can be told apart.
// `flutter build appbundle` runs bundleRelease.
val isBundleBuild = gradle.startParameter.taskNames.any {
    it.substringAfterLast(':').startsWith("bundle")
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
        // Each is populated from key.properties when its key is configured and
        // left empty otherwise (the release build type falls back to debug
        // signing below).
        create("release") {
            if (hasAppSigningKey) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
        create("upload") {
            if (hasUploadKey) {
                keyAlias = keystoreProperties["uploadKeyAlias"] as String
                keyPassword = keystoreProperties["uploadKeyPassword"] as String
                storeFile = file(keystoreProperties["uploadStoreFile"] as String)
                storePassword = keystoreProperties["uploadStorePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // An App Bundle is only ever signed with the upload key, and an APK
            // only with the app-signing key. A bundle never falls back to the
            // app-signing key: the first bundle Play receives registers its
            // signer as the upload key, which would quietly undo the separation.
            // A debug-signed bundle, by contrast, Play refuses outright.
            signingConfig = when {
                isBundleBuild && hasUploadKey -> signingConfigs.getByName("upload")
                isBundleBuild -> signingConfigs.getByName("debug")
                hasAppSigningKey -> signingConfigs.getByName("release")
                else -> signingConfigs.getByName("debug")
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
