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
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureAndroid = {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            for (m in androidExt.javaClass.methods) {
                if (m.name.equals("setCompileSdkVersion", ignoreCase = true) || 
                    m.name.equals("setCompileSdk", ignoreCase = true) || 
                    m.name == "compileSdkVersion") {
                    try {
                        if (m.parameterTypes.size == 1) {
                            val paramType = m.parameterTypes[0]
                            if (paramType == java.lang.Integer::class.java || paramType == Int::class.javaPrimitiveType) {
                                m.invoke(androidExt, 36)
                            }
                        }
                    } catch (_: Exception) {}
                }
            }
        }
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
