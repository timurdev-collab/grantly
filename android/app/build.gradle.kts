plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Reuse client-safe public settings from the existing iOS project.
val iosSettings = rootProject.file("../project.yml").takeIf { it.exists() }?.readLines().orEmpty()
val catalogUrl = iosSettings.firstOrNull { it.trim().startsWith("SUPABASE_URL: https://") }
    ?.substringAfter(": ")?.trim().orEmpty()
val catalogPublicKey = iosSettings.firstOrNull { it.trim().startsWith("SUPABASE_PUBLISHABLE_KEY: sb_publishable_") }
    ?.substringAfter(": ")?.trim().orEmpty()

android {
    namespace = "com.grantly.android"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.grantly.android"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.2.0"
        buildConfigField("String", "SUPABASE_URL", "\"$catalogUrl\"")
        buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"$catalogPublicKey\"")
    }
    buildTypes {
        release { isMinifyEnabled = false }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true; buildConfig = true }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
