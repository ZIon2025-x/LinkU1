import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing: load keystore config if available
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.link2ur.link2ur"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.link2ur"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Read Google Maps API Key from local.properties
        val localProperties = Properties()
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { localProperties.load(it) }
        }
        manifestPlaceholders["MAPS_API_KEY"] = localProperties.getProperty("MAPS_API_KEY", "")
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // AAB（bundleRelease）由 Google Play 按 ABI 自动拆分，不应在本地再启用 ABI splits。
    // 否则会触发 buildReleasePreBundle 的 multiple shrunk-resources 冲突。
    splits {
        abi {
            isEnable = false
            reset()
            include("armeabi-v7a", "arm64-v8a")
            isUniversalApk = false
        }
    }

    buildTypes {
        release {
            // R8 代码压缩 + 资源压缩：减少 APK 体积 30-50%，提升启动速度
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Stripe：flutter_stripe stripe_android 使用 22.2.+，stripe-connect 使用 22.8.0，
// 版本混用导致 NoClassDefFoundError: SectionFieldErrorController（uicore 与 lpm-foundations 不一致）
// 强制统一为 22.8.0
configurations.all {
    resolutionStrategy {
        force("com.stripe:stripe-android:22.8.0")
        force("com.stripe:financial-connections:22.8.0")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Flutter embedding 在 release + R8 下会引用 splitinstall/splitcompat 类
    // 使用 feature-delivery（新拆分依赖）避免与 review/core-common 重复类冲突
    implementation("com.google.android.play:feature-delivery:2.1.0")
    // Firebase BOM + FCM
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging-ktx")
    // Google Maps SDK
    implementation("com.google.android.gms:play-services-maps:19.0.0")
    implementation("com.google.android.gms:play-services-location:21.3.0")
    // Material Components (for MaterialButton, FAB in location picker)
    implementation("com.google.android.material:material:1.12.0")
    // AppCompat (LocationPickerActivity extends AppCompatActivity)
    implementation("androidx.appcompat:appcompat:1.7.0")
    // Stripe Connect（与 flutter_stripe 12.x 共用 stripe-android 22.8）
    implementation("com.stripe:connect:22.8.0")
    // Google Pay（Stripe Platform Pay 在 Android 上需要）
    implementation("com.google.android.gms:play-services-wallet:19.3.0")
    // ViewModel (Stripe 文档推荐 EmbeddedComponentManager 放在 ViewModel 中)
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.7")
    implementation("androidx.activity:activity-ktx:1.9.3")
}

flutter {
    source = "../.."
}
