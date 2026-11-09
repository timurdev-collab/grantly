plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Read the explicit iOS Debug configuration as a compatibility fallback, not the
// first matching value anywhere in project.yml (which also defines staging).
// Android-specific Gradle properties can override both public client settings.
val iosSettings = rootProject.file("../project.yml").takeIf { it.exists() }?.readLines().orEmpty()
val debugSettings = iosSettings.dropWhile { it.trim() != "Debug:" }
    .drop(1).takeWhile { it.startsWith("          ") }
fun debugSetting(name: String): String = debugSettings
    .firstOrNull { it.trim().startsWith("$name: ") }
    ?.substringAfter(": ")?.trim().orEmpty()
val catalogUrl = providers.gradleProperty("edutSupabaseUrl").orNull
    ?: debugSetting("SUPABASE_URL")
val catalogPublicKey = providers.gradleProperty("edutSupabasePublishableKey").orNull
    ?: debugSetting("SUPABASE_PUBLISHABLE_KEY")
require(catalogUrl.startsWith("https://") && catalogUrl.endsWith(".supabase.co")) {
    "Missing or invalid Android Supabase URL (edutSupabaseUrl)"
}
require(catalogPublicKey.startsWith("sb_publishable_")) {
    "Missing Android publishable key (edutSupabasePublishableKey); never use a secret/service-role key"
}

// The upload key stays on the developer's machine. No passwords or private keys
// are stored in the repository or sent to GitHub Actions.
val uploadKeyFile = file(
    providers.environmentVariable("EDUT_UPLOAD_KEYSTORE").orNull
        ?: "${System.getProperty("user.home")}/EduT-Android-Signing/edut-upload-key.p12"
)
val uploadStorePassword = providers.environmentVariable("EDUT_UPLOAD_STORE_PASSWORD").orNull
val uploadKeyPassword = providers.environmentVariable("EDUT_UPLOAD_KEY_PASSWORD").orNull
    ?: uploadStorePassword
val uploadSigningReady = uploadKeyFile.isFile && !uploadStorePassword.isNullOrBlank() &&
    !uploadKeyPassword.isNullOrBlank()

android {
    // Kotlin source namespace remains unchanged; Google Play identity is applicationId.
    namespace = "com.grantly.android"
    compileSdk = 35

    defaultConfig {
        // Permanent Google Play package name. Never change after the first Play upload.
        applicationId = "com.edut.scholarship"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField("String", "SUPABASE_URL", "\"$catalogUrl\"")
        buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"$catalogPublicKey\"")
    }
    signingConfigs {
        if (uploadSigningReady) {
            create("edutUpload") {
                storeFile = uploadKeyFile
                storePassword = uploadStorePassword
                keyAlias = "edut-upload"
                keyPassword = uploadKeyPassword
                storeType = "pkcs12"
            }
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            if (uploadSigningReady) signingConfig = signingConfigs.getByName("edutUpload")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true; buildConfig = true }
}

// Fail closed: never generate an unsigned artifact that could be mistaken for
// the Google Play upload bundle when local signing credentials are absent.
val verifyEduTUploadSigning = tasks.register("verifyEduTUploadSigning") {
    doLast {
        check(uploadSigningReady) {
            "Release signing unavailable. Set EDUT_UPLOAD_STORE_PASSWORD and ensure the local " +
                "EduT-Android-Signing/edut-upload-key.p12 file exists. Never commit credentials."
        }
    }
}
tasks.matching { it.name == "bundleRelease" || it.name == "assembleRelease" }
    .configureEach { dependsOn(verifyEduTUploadSigning) }

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
    testImplementation("junit:junit:4.13.2")
    // The instrumentation classpath needs its own Compose BOM; implementation BOM is not inherited.
    androidTestImplementation(platform("androidx.compose:compose-bom:2024.12.01"))
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
    // Compose semantics actions are synchronized with recomposition; avoid flaky UIAutomator taps.
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
}
