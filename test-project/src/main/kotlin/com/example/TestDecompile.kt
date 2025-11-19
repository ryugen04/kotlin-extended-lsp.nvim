package com.example

import io.ktor.server.application.*
import io.ktor.server.routing.*
import io.ktor.server.response.*
import org.jetbrains.exposed.sql.Table
import org.koin.core.context.startKoin
import org.koin.dsl.module

/**
 * デコンパイル機能のテストファイル
 *
 * 以下のシンボルにカーソルを置いて gd または :KotlinDecompile を実行:
 * - Application (Ktor)
 * - Table (Exposed)
 * - startKoin (Koin)
 */

// Ktor Application の拡張関数
fun Application.testModule() {
    routing {
        get("/test") {
            // カーソルを Application, routing, get, call, respondText に置いてテスト
            call.respondText("Test decompile feature")
        }
    }
}

// Exposed Table の使用例
object Users : Table() {
    val id = integer("id").autoIncrement()
    val name = varchar("name", 50)

    override val primaryKey = PrimaryKey(id)
}

// Koin の使用例
val appModule = module {
    single { "Test Service" }
}

fun testKoin() {
    startKoin {
        modules(appModule)
    }
}
