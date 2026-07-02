import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties =
    Properties().apply {
        if (releaseSigningPropertiesFile.isFile) {
            releaseSigningPropertiesFile.inputStream().use { input -> load(input) }
        }
    }

fun signingValue(envName: String, propertyName: String): String? =
    providers.environmentVariable(envName).orNull?.takeIf { it.isNotBlank() }
        ?: releaseSigningProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val releaseStoreFilePath = signingValue("WIDENOTE_ANDROID_KEYSTORE_FILE", "storeFile")
val releaseStorePassword = signingValue("WIDENOTE_ANDROID_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("WIDENOTE_ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("WIDENOTE_ANDROID_KEY_PASSWORD", "keyPassword")
val releaseStoreFile = releaseStoreFilePath?.let { rootProject.file(it) }
val releaseSigningProblems =
    buildList {
        if (releaseStoreFilePath == null) add("storeFile / WIDENOTE_ANDROID_KEYSTORE_FILE")
        if (releaseStorePassword == null) add("storePassword / WIDENOTE_ANDROID_KEYSTORE_PASSWORD")
        if (releaseKeyAlias == null) add("keyAlias / WIDENOTE_ANDROID_KEY_ALIAS")
        if (releaseKeyPassword == null) add("keyPassword / WIDENOTE_ANDROID_KEY_PASSWORD")
        if (releaseStoreFilePath != null && releaseStoreFile?.isFile != true) {
            add("keystore file does not exist: $releaseStoreFilePath")
        }
    }
val hasReleaseSigning = releaseSigningProblems.isEmpty()
val releaseSigningHelp =
    """
    Android prod release signing is required.
    Configure either environment variables:
      WIDENOTE_ANDROID_KEYSTORE_FILE
      WIDENOTE_ANDROID_KEYSTORE_PASSWORD
      WIDENOTE_ANDROID_KEY_ALIAS
      WIDENOTE_ANDROID_KEY_PASSWORD
    or apps/mobile/android/key.properties with:
      storeFile=<absolute path or path relative to apps/mobile/android>
      storePassword=<secret>
      keyAlias=<alias>
      keyPassword=<secret>
    Missing: ${releaseSigningProblems.joinToString(", ")}
    Dev release builds intentionally keep debug signing for local QA.
    """.trimIndent()

android {
    namespace = "app.widenote"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val productionApplicationId = "app.widenote"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = productionApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("prodRelease") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    flavorDimensions += "releaseChannel"
    productFlavors {
        create("prod") {
            dimension = "releaseChannel"
            applicationId = productionApplicationId
            manifestPlaceholders["appLabel"] = "WideNote"
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("prodRelease")
            }
        }
        create("dev") {
            dimension = "releaseChannel"
            applicationId = "$productionApplicationId.dev"
            manifestPlaceholders["appLabel"] = "WideNote Dev"
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildTypes {
        release {
            // Release signing is selected per flavor: devRelease uses debug signing
            // for local QA, while prodRelease requires configured release signing.
        }
    }
}

gradle.taskGraph.whenReady {
    val prodReleaseRequested =
        allTasks.any { task ->
            task.path.contains("ProdRelease", ignoreCase = true) ||
                task.name.contains("ProdRelease", ignoreCase = true)
        }
    if (prodReleaseRequested && !hasReleaseSigning) {
        throw GradleException(releaseSigningHelp)
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}
