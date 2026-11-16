import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension

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
    afterEvaluate {
        // Kotlin: fijar jvmTarget explícito (jvmToolchain no pisa un jvmTarget ya declarado)
        extensions.findByType<KotlinAndroidProjectExtension>()?.apply {
            compilerOptions {
                jvmTarget.set(JvmTarget.JVM_17)
            }
        }
        // Forzar Java 17 en módulos Android
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val compileOptions = androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java).invoke(compileOptions, JavaVersion.VERSION_17)
                compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java).invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (_: Exception) {}
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
