plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 🚀 MASTER TOOLCHAIN: Sets the entire project environment to Java 17
kotlin {
    jvmToolchain(17)
}

android {
    namespace = "com.example.fruitclassification"
    // 🚀 BUMPED TO 36: Required by your updated camera, file_picker, and tflite plugins
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Force Kotlin tasks for the main app to use 17
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.example.fruitclassification"
        minSdk = 24
        // 🚀 BUMPED TO 36: Matches your latest dependency requirements
        targetSdk = 36
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    androidResources {
        noCompress.addAll(listOf("tflite", "lite"))
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// ☢️ THE ABSOLUTE GLOBAL OVERRIDE
// This forces EVERY plugin (especially receive_sharing_intent) to match Java 17
subprojects {
    afterEvaluate {
        // Force the Android/Java side of every plugin to 17
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }

        // Force the Kotlin side of every plugin to 17 (Kills the '21' error)
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                // This flag ensures the compiler strictly follows the Java 17 API
                freeCompilerArgs.add("-Xjdk-release=17")
            }
        }

        // Force general Java tasks to 17 (Kills the '1.8' error)
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }
}