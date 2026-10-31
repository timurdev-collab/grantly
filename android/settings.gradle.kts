pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // Required by LiveKit Android SDK transitive dependencies.
        maven { url = uri("https://jitpack.io") }
    }
}
rootProject.name = "EduTAndroid"
include(":app")
