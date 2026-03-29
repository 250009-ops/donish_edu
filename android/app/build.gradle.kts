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

android {
    namespace = "uz.donish.edu"
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
        applicationId = "uz.donish.edu"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
        release {
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
