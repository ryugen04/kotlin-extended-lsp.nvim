plugins {
    kotlin("jvm") version "1.9.23"
    kotlin("plugin.serialization") version "1.9.23"
    id("io.gitlab.arturbosch.detekt") version "1.23.8"
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
    application
}

group = "com.example"
version = "1.0.0"

repositories {
    mavenCentral()
    google()
}

dependencies {
    // Kotlin標準ライブラリ
    implementation(kotlin("stdlib"))
    implementation(kotlin("reflect"))

    // Coroutines（非同期処理）
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")

    // Serialization（JSON処理）
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

    // Arrow（関数型プログラミング）
    implementation("io.arrow-kt:arrow-core:1.2.3")

    // Ktor（サーバーサイドフレームワーク）
    implementation("io.ktor:ktor-server-core:2.3.9")
    implementation("io.ktor:ktor-server-netty:2.3.9")
    implementation("io.ktor:ktor-server-content-negotiation:2.3.9")
    implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.9")

    // Exposed（データベースORM）
    implementation("org.jetbrains.exposed:exposed-core:0.48.0")
    implementation("org.jetbrains.exposed:exposed-dao:0.48.0")
    implementation("org.jetbrains.exposed:exposed-jdbc:0.48.0")
    implementation("org.jetbrains.exposed:exposed-java-time:0.48.0")

    // データベースドライバ
    implementation("com.h2database:h2:2.2.224")

    // DI（Dependency Injection）
    implementation("io.insert-koin:koin-core:3.5.6")
    implementation("io.insert-koin:koin-ktor:3.5.6")

    // ロギング
    implementation("io.github.microutils:kotlin-logging-jvm:3.0.5")
    implementation("ch.qos.logback:logback-classic:1.4.14")

    // テスト
    testImplementation(kotlin("test"))
    testImplementation("io.kotest:kotest-runner-junit5:5.8.0")
    testImplementation("io.kotest:kotest-assertions-core:5.8.0")
    testImplementation("io.kotest:kotest-property:5.8.0")
    testImplementation("io.mockk:mockk:1.13.10")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.0")
    testImplementation("io.ktor:ktor-server-test-host:2.3.9")

    // Detektプラグイン
    detektPlugins("io.gitlab.arturbosch.detekt:detekt-formatting:1.23.8")
}

// Kotlinコンパイル設定
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        jvmTarget = "21"
        freeCompilerArgs = listOf(
            "-Xjsr305=strict",
            "-opt-in=kotlin.RequiresOptIn",
            "-Xcontext-receivers"
        )
    }
}

// テスト設定
tasks.test {
    useJUnitPlatform()
}

// Application設定
application {
    mainClass.set("com.example.ApplicationKt")
}

// Detekt設定
detekt {
    buildUponDefaultConfig = true
    allRules = false
    config.setFrom("$projectDir/detekt.yml")
    parallel = true
}

tasks.withType<io.gitlab.arturbosch.detekt.Detekt>().configureEach {
    jvmTarget = "21"
    reports {
        html.required.set(true)
        sarif.required.set(true)
        sarif.outputLocation.set(file("$projectDir/build/reports/detekt.sarif"))
    }
}

// ktlint設定
ktlint {
    version.set("1.0.1")
    android.set(false)
    filter {
        exclude("**/generated/**")
        exclude("**/build/**")
    }
}
