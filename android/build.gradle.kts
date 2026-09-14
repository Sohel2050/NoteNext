allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Safety net: some older plugins don't declare a namespace in their own
// android/build.gradle, which newer AGP (8+) requires. This fills it in
// from the plugin's `group` if missing, instead of failing the build.
// IMPORTANT: this must be registered BEFORE evaluationDependsOn(":app")
// below, otherwise :app is already evaluated by the time we hook
// afterEvaluate on it, and Gradle throws "already evaluated".
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            if (androidExt != null && androidExt.namespace == null) {
                androidExt.namespace = project.group.toString()
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
