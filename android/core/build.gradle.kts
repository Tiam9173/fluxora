plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "io.fluxora.core"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        minSdk = 26
    }

    buildTypes {
        release {
            isJniDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    externalNativeBuild {
        cmake {
            path("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
dependencies {
    implementation("androidx.annotation:annotation-jvm:1.9.1")
}

val copyNativeLibs by tasks.register<Copy>("copyNativeLibs") {
    doFirst {
        delete("src/main/jniLibs")
    }
    from("../../libclash/android")
    into("src/main/jniLibs")
}

afterEvaluate {
    tasks.named("preBuild") {
        dependsOn(copyNativeLibs)
    }
    // CMake decides whether to link libclash by testing whether the file exists
    // (see CMakeLists.txt: LIB_CLASH_PATH). copyNativeLibs deletes and rewrites
    // src/main/jniLibs, so without this dependency the configure step can run
    // first, see nothing, and silently build a libcore.so that links no core —
    // the app then starts fine and dies with UnsatisfiedLinkError on startTun.
    tasks.matching { it.name.startsWith("configureCMake") }.configureEach {
        dependsOn(copyNativeLibs)
    }
}