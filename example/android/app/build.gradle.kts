plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.tripos_mobile_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.tripos_mobile_example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        // minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/*.kotlin_module"
            )
        }
        jniLibs {
            pickFirsts += "lib/*/libtlvtree.so"
            pickFirsts += "lib/*/libpcltools.so"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    // triPOS SDK AAR 文件 - 通过插件的 flatDir 仓库自动解析
    implementation(mapOf("name" to "triposmobilesdk-release", "ext" to "aar"))
    implementation(mapOf("name" to "rba_sdk", "ext" to "aar"))
    implementation(mapOf("name" to "roamreaderunifiedapi-2.5.3.100-release", "ext" to "aar"))
    implementation(mapOf("name" to "retail-types-release-22.01.06.01-0010", "ext" to "aar"))
    implementation(mapOf("name" to "ux-server-release-22.01.06.01-0010", "ext" to "aar"))
    implementation(mapOf("name" to "PclServiceLib_2.21.02", "ext" to "aar"))
    implementation(mapOf("name" to "PclUtilities_2.21.02", "ext" to "aar"))
    implementation(mapOf("name" to "iPclBridge", "ext" to "aar"))
}

