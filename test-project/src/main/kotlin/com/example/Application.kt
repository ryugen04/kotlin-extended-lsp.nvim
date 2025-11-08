package com.example

import com.example.api.userRoutes
import com.example.config.allModules
import com.example.service.UserService
import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.json.Json
import mu.KotlinLogging
import org.koin.ktor.ext.inject
import org.koin.ktor.plugin.Koin

/**
 * アプリケーションエントリーポイント
 * LSPテスト項目:
 * - main関数の定義と実行
 * - Ktor DSLの型解決とシグネチャヘルプ
 * - プラグイン設定のナビゲーション
 */
fun main() {
    val logger = KotlinLogging.logger {}
    logger.info { "Starting application..." }

    embeddedServer(Netty, port = 8080, host = "0.0.0.0", module = Application::module)
        .start(wait = true)
}

/**
 * Ktorアプリケーションモジュール
 * LSPテスト項目:
 * - 拡張関数レシーバーの型解決
 * - Koin injectionの型推論
 * - ルーティングDSLのナビゲーション
 */
fun Application.module() {
    val logger = KotlinLogging.logger {}

    // Koin DIコンテナ設定
    install(Koin) {
        modules(allModules)
    }

    // JSON シリアライゼーション設定
    install(ContentNegotiation) {
        json(Json {
            prettyPrint = true
            isLenient = true
            ignoreUnknownKeys = true
        })
    }

    // ルーティング設定
    routing {
        // ヘルスチェック
        get("/health") {
            call.respond(mapOf("status" to "UP"))
        }

        // ユーザーAPI
        // LSPテスト: Koin injectionの型解決とメソッド呼び出し
        val userService by inject<UserService>()
        userRoutes(userService)
    }

    logger.info { "Application module configured" }
}
