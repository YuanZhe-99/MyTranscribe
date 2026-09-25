import java.util.Properties

plugins {
    id("com.android.application")
    // Built-in Kotlin: the app no longer applies the Kotlin Gradle Plugin
    // itself (Flutter/AGP provide Kotlin support). The KGP version stays
    // declared in settings.gradle.kts because several Flutter plugins still
    // apply KGP and resolve it from there.
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.yuanzhe.my_transcribe"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.yuanzhe.my_transcribe"
        // 24 is the Flutter default and what the bundled FFmpeg libraries
        // require; nothing in this app needs more. See
        // doc/en-us/platform-notes.md.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"]!!)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    // Native libraries are extracted to the app's native library directory
    // rather than read from inside the APK: whisper.cpp's ggml lists that
    // directory to find the CPU variant that suits this phone, and a folder
    // inside an APK cannot be listed. See doc/en-us/platform-notes.md.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Built-in Kotlin migration: align the Kotlin jvmTarget with the Java 17
// compileOptions above. Without this, Kotlin defaults to the running JDK's
// target and the build fails with an Inconsistent JVM Target error.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
