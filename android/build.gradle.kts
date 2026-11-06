
// Aliyun's Maven mirror makes local builds in mainland China bearable, but it is
// a third-party hop we do not control. On 2026-11-05 it answered HTTP 502 for
// `org/apache/commons/commons-parent/35/...pom`; Gradle does not fall through to
// the next repository on a 5xx — it disables the repository ("disabled due to
// earlier error") and the whole dependency graph fails to resolve, which took
// down the Android amd64 release build while every other platform passed.
// GitHub runners reach Google/Maven Central directly, so CI skips the mirror.
val useAliyunMirror = System.getenv("CI") != "true"

allprojects {
    repositories {
        if (useAliyunMirror) {
            maven("https://maven.aliyun.com/repository/google")
            maven("https://maven.aliyun.com/repository/public")
            maven("https://maven.aliyun.com/repository/gradle-plugin")
        }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    if (project.projectDir.toPath().root == rootProject.projectDir.toPath().root) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}