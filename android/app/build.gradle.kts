plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.getprio.getprio_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.getprio.getprio_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["getPrioLinkHost"] = "getprio.online"
        manifestPlaceholders["getPrioAppScheme"] = "getprio"
    }

    flavorDimensions += "environment"

    productFlavors {
        create("production") {
            dimension = "environment"
            applicationId = "com.getprio.getprio_mobile"
            resValue("string", "app_name", "getprio_mobile")
            manifestPlaceholders["getPrioLinkHost"] = "getprio.online"
            manifestPlaceholders["getPrioAppScheme"] = "getprio"
        }

        create("sandbox") {
            dimension = "environment"
            applicationId = "com.getprio.getprioMobile.android.sandbox"
            resValue("string", "app_name", "GetPrio Sandbox")
            manifestPlaceholders["getPrioLinkHost"] = "sandbox.getprio.online"
            manifestPlaceholders["getPrioAppScheme"] = "getprio-sandbox"
        }

        // Sandbox Firebase options are supplied by the Flutter runtime. If a
        // local google-services.json is present, process it for native tooling;
        // never fall back to the production file for a sandbox variant.
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so
            // `flutter run --flavor production --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

tasks.matching {
    it.name.startsWith("processSandbox") && it.name.endsWith("GoogleServices")
}.configureEach {
    onlyIf {
        file("src/sandbox/google-services.json").exists()
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
