plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ling.lingos.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // 【修复】flutter_local_notifications 需要 core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ling.lingos.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24) // 【A5】Shizuku 要求 minSdk>=24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName // 【0.1.9修复】动态取 pubspec 版本（曾硬编码 0.1.8 覆盖导致版本不更新）
    }

    // 【正式签名】统一 release 签名（可覆盖安装——先生决策 A）
    signingConfigs {
        create("release") {
            storeFile = file("../../lingos-release.jks")
            storePassword = "lingos2026"
            keyAlias = "lingos"
            keyPassword = "lingos2026"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

dependencies {
    // 【修复】flutter_local_notifications core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
