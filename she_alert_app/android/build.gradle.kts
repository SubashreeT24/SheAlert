allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

allprojects {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            extensions.getByType<com.android.build.gradle.BaseExtension>().apply {
                compileSdkVersion(34)
            }
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}