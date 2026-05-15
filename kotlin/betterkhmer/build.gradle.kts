plugins {
    kotlin("jvm") version "2.0.0"
    application
}

group = "com.betterkhmer"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(kotlin("test"))
}

kotlin {
    jvmToolchain(17)
}

application {
    mainClass.set("com.betterkhmer.BetterKhmerTestKt")
}

tasks.test {
    useJUnitPlatform()
    systemProperty("fixtures.dir", project.findProperty("fixturesDir")
        ?: "${projectDir}/../../fixtures")
    jvmArgs("-Dfile.encoding=UTF-8")
}

tasks.jar {
    manifest { attributes["Main-Class"] = "com.betterkhmer.BetterKhmerTestKt" }
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
}
