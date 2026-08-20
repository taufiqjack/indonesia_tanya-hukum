import com.android.build.OutputFile
import com.android.build.gradle.internal.api.BaseVariantOutputImpl
import com.android.build.gradle.internal.tasks.FinalizeBundleTask
import java.text.SimpleDateFormat
import java.util.Date

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jetorbit.indonesia_law"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jetorbit.indonesia_law"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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
}

// Name the artifacts TanyaHukum-v<version>_<date>[_<abi>]_<variant>.apk / .aab
val buildDate: String = SimpleDateFormat("ddMMyyyy").format(Date())
val buildDirectory = layout.buildDirectory

android.applicationVariants.all {
    val variantName = name
    val variantVersionName = versionName
    val variantVersionCode = versionCode

    outputs.all {
        val output = this as BaseVariantOutputImpl
        val abi = output.getFilter(OutputFile.ABI)
        output.outputFileName = if (abi != null) {
            "TanyaHukum-v${variantVersionName}_${buildDate}_${abi}_$variantName.apk"
        } else {
            "TanyaHukum-v${variantVersionName}_${buildDate}_$variantName.apk"
        }
    }

    // FinalizeBundleTask has no value for finalBundleFile while it is being created,
    // so set the destination outright rather than deriving it from the current value.
    val bundleTaskName = "sign${variantName.replaceFirstChar { it.uppercase() }}Bundle"
    tasks.withType(FinalizeBundleTask::class.java)
        .matching { it.name == bundleTaskName }
        .configureEach {
            finalBundleFile.set(
                buildDirectory.file(
                    "outputs/bundle/$variantName/" +
                        "TanyaHukum-$variantName-v$variantVersionName+$variantVersionCode-$buildDate.aab",
                ),
            )
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
