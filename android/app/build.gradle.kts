import java.util.Properties
import com.flutter.gradle.tasks.FlutterTask

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties for release signing
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.fusionwave.duelMultiplayerQuiz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    androidResources {
        // Store all these file types UNCOMPRESSED (no DEFLATE) in the AAB/APK.
        // Covers everything Flutter ships in flutter_assets plus common asset formats.
        noCompress += listOf(
            "aab",
            "assets",
            "bin",
            "dex",
            "frag",
            "font",
            "jpg",
            "jpeg",
            "json",
            "mp3",
            "mp4",
            "ogg",
            "otf",
            "png",
            "ttf",
            "wav",
            "webm",
            "webp",
            "zip",
        )
    }

    defaultConfig {
        applicationId = "com.fusionwave.duelMultiplayerQuiz"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            // file() resolves relative to android/app/, so 'upload-keystore.jks'
            // in key.properties works regardless of the Gradle daemon's CWD.
            storeFile = keyProperties["storeFile"]?.let { file(it as String) }
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            // Explicitly disable R8 code minification and resource shrinking.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// The flutter tool always passes -Ptree-shake-icons from the CLI (which outranks
// gradle.properties), and the plugin's task configuration can run after script-level
// rules. Setting it in whenReady — after all configuration, before execution — wins.
gradle.taskGraph.whenReady {
    allTasks.forEach { task ->
        if (task is FlutterTask) {
            task.treeShakeIcons = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
