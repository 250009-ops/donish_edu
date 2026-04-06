import java.io.StringReader
import java.nio.charset.StandardCharsets
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystoreFile = keystorePropertiesFile.exists()
if (hasReleaseKeystoreFile) {
    val raw = keystorePropertiesFile.readText(StandardCharsets.UTF_8).trimStart('\uFEFF')
    StringReader(raw).use { keystoreProperties.load(it) }
}

fun Properties.nonBlank(name: String): String? =
    getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

val releaseSigningReady =
    hasReleaseKeystoreFile &&
        listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
            .all { keystoreProperties.nonBlank(it) != null }

// Guard against stale local.properties values during release uploads.
// Bump these together with each Play release (must match or stay below pubspec version).
// pubspec.yaml: version: 1.0.0+1  →  name 1.0.0, versionCode 1 (new Play listing)
val minReleaseVersionCode = 1
val minReleaseVersionName = "1.0.0"

android {
    namespace = "uz.donish"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "uz.donish"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        val resolvedVersionCode = maxOf(flutter.versionCode, minReleaseVersionCode)
        versionCode = resolvedVersionCode
        versionName = if (resolvedVersionCode == minReleaseVersionCode) {
            minReleaseVersionName
        } else {
            flutter.versionName.ifBlank { minReleaseVersionName }
        }
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                keyAlias = keystoreProperties.nonBlank("keyAlias")!!
                keyPassword = keystoreProperties.nonBlank("keyPassword")!!
                storeFile = rootProject.file(keystoreProperties.nonBlank("storeFile")!!)
                storePassword = keystoreProperties.nonBlank("storePassword")!!
            }
        }
    }

    buildTypes {
        debug {
            // Single ABI avoids parallel CMake configure tasks that often race on Windows file locks.
            ndk {
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
            }
        }
        release {
            // Windows: limit native ABIs so CMake configure tasks do not run in parallel
            // (avoids "file is being used by another process" in cxx metadata). Play still
            // gets 64-bit (required). Add "armeabi-v7a" if you need 32-bit ARM devices.
            ndk {
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
            }
            signingConfig =
                if (releaseSigningReady) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
