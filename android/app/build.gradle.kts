import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.devtools.ksp")
}

val localProps = Properties().also { props ->
    val f = rootProject.file("local.properties")
    if (f.exists()) props.load(f.inputStream())
}
val releaseKeystorePath = localProps.getProperty("KEYSTORE_PATH")
val releaseKeystoreFile = releaseKeystorePath?.let { rootProject.file(it) }
val hasReleaseSigning = releaseKeystoreFile?.exists() == true &&
    localProps.getProperty("KEYSTORE_PASSWORD") != null &&
    localProps.getProperty("KEY_ALIAS") != null &&
    localProps.getProperty("KEY_PASSWORD") != null

android {
    namespace = "com.sortyd.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.sortyd.app"
        minSdk = 28
        targetSdk = 35
        versionCode = 1
        versionName = "1.7.3"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = localProps.getProperty("KEYSTORE_PASSWORD")
                keyAlias = localProps.getProperty("KEY_ALIAS")
                keyPassword = localProps.getProperty("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    // ── Behaviour analytics ──
    implementation("com.microsoft.clarity:clarity-compose:3.8.3")

    // ── Compose BOM ──
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // ── Core ──
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.core:core-splashscreen:1.2.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")

    // ── Navigation ──
    implementation("androidx.navigation:navigation-compose:2.8.5")

    // ── Room (persistence) ──
    val roomVersion = "2.6.1"
    implementation("androidx.room:room-runtime:$roomVersion")
    implementation("androidx.room:room-ktx:$roomVersion")
    ksp("androidx.room:room-compiler:$roomVersion")

    // ── DataStore (preferences) ──
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // ── Health Connect ──
    implementation("androidx.health.connect:connect-client:1.1.0-alpha07")

    // ── WorkManager (background sync) ──
    implementation("androidx.work:work-runtime-ktx:2.10.0")

    // ── Google Fonts ──
    implementation("androidx.compose.ui:ui-text-google-fonts:1.7.6")

    // ── In-App Review ──
    implementation("com.google.android.play:review-ktx:2.0.2")

    // ── Kotlin serialization (for JSON in Room converters) ──
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // ── Jetpack Glance (Widgets) ──
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")

    // ── Testing ──
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
