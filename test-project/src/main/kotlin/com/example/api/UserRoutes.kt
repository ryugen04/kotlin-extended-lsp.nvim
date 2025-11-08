package com.example.api

import com.example.domain.Email
import com.example.domain.UserId
import com.example.domain.UserRole
import com.example.service.ServiceError
import com.example.service.UserService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable

/**
 * ユーザーAPI定義
 * LSPテスト項目:
 * - Ktor DSLのナビゲーション
 * - ラムダレシーバーの型解決
 * - 拡張関数（Routing）の参照
 */
fun Route.userRoutes(userService: UserService) {
    route("/users") {
        // ユーザー一覧取得
        get {
            val limit = call.request.queryParameters["limit"]?.toIntOrNull() ?: 100
            val offset = call.request.queryParameters["offset"]?.toIntOrNull() ?: 0

            userService.listUsers(limit, offset)
                .fold(
                    ifLeft = { error -> call.respondError(error) },
                    ifRight = { users -> call.respond(users.map { it.toResponse() }) }
                )
        }

        // ユーザー作成
        post {
            val request = call.receive<CreateUserRequest>()

            userService.createUser(
                email = request.email,
                name = request.name,
                role = UserRole.valueOf(request.role)
            ).fold(
                ifLeft = { error -> call.respondError(error) },
                ifRight = { user -> call.respond(HttpStatusCode.Created, user.toResponse()) }
            )
        }

        // ユーザーID取得
        get("/{id}") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: return@get call.respond(HttpStatusCode.BadRequest, "Invalid user ID")

            userService.getUserById(UserId(id))
                .fold(
                    ifLeft = { error -> call.respondError(error) },
                    ifRight = { user -> call.respond(user.toResponse()) }
                )
        }

        // ユーザー更新
        put("/{id}") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: return@put call.respond(HttpStatusCode.BadRequest, "Invalid user ID")

            val request = call.receive<UpdateUserRequest>()

            userService.getUserById(UserId(id))
                .fold(
                    ifLeft = { error -> call.respondError(error) },
                    ifRight = { user ->
                        val updated = user.copy(
                            name = com.example.domain.UserName(request.name),
                            role = UserRole.valueOf(request.role)
                        )
                        userService.updateUser(updated)
                            .fold(
                                ifLeft = { error -> call.respondError(error) },
                                ifRight = { u -> call.respond(u.toResponse()) }
                            )
                    }
                )
        }

        // ユーザー削除
        delete("/{id}") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: return@delete call.respond(HttpStatusCode.BadRequest, "Invalid user ID")

            userService.deleteUser(UserId(id))
                .fold(
                    ifLeft = { error -> call.respondError(error) },
                    ifRight = { call.respond(HttpStatusCode.NoContent) }
                )
        }

        // ユーザー検索（メールアドレス）
        get("/by-email/{email}") {
            val email = call.parameters["email"]
                ?: return@get call.respond(HttpStatusCode.BadRequest, "Email required")

            userService.getUserByEmail(Email(email))
                .fold(
                    ifLeft = { error -> call.respondError(error) },
                    ifRight = { user -> call.respond(user.toResponse()) }
                )
        }

        // ユーザーアクティベート
        post("/{id}/activate") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: return@post call.respond(HttpStatusCode.BadRequest, "Invalid user ID")

            userService.activateUser(UserId(id))
                .fold(
                    ifLeft = { error -> call.respondError(error) },
                    ifRight = { user -> call.respond(user.toResponse()) }
                )
        }

        // ユーザーサスペンド
        post("/{id}/suspend") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: return@post call.respond(HttpStatusCode.BadRequest, "Invalid user ID")

            val request = call.receive<SuspendUserRequest>()

            userService.suspendUser(UserId(id), request.reason)
                .fold(
                    ifLeft = { error -> call.respondError(error) },
                    ifRight = { user -> call.respond(user.toResponse()) }
                )
        }
    }
}

/**
 * リクエスト/レスポンスDTO
 * LSPテスト項目:
 * - Serializable data classの型定義
 * - ネストされたオブジェクトの構造ナビゲーション
 */
@Serializable
data class CreateUserRequest(
    val email: String,
    val name: String,
    val role: String = "USER"
)

@Serializable
data class UpdateUserRequest(
    val name: String,
    val role: String
)

@Serializable
data class SuspendUserRequest(
    val reason: String
)

@Serializable
data class UserResponse(
    val id: Long,
    val email: String,
    val name: String,
    val role: String,
    val status: String,
    val createdAt: String,
    val updatedAt: String
)

/**
 * エラーレスポンス
 */
@Serializable
data class ErrorResponse(
    val error: String,
    val message: String
)

/**
 * 拡張関数: DomainモデルをResponseに変換
 * LSPテスト項目:
 * - 拡張関数の定義と使用箇所のジャンプ
 * - ドメインモデルへの参照解決
 */
private fun com.example.domain.User.toResponse(): UserResponse = UserResponse(
    id = this.id.value,
    email = this.email.value,
    name = this.name.value,
    role = this.role.name,
    status = this.status.label,
    createdAt = this.createdAt,
    updatedAt = this.updatedAt
)

/**
 * 拡張関数: エラーレスポンス送信
 * LSPテスト項目:
 * - suspend拡張関数のシグネチャヘルプ
 * - when式での型の網羅性チェック
 */
private suspend fun ApplicationCall.respondError(error: ServiceError) {
    val (status, errorType) = when (error) {
        is ServiceError.NotFound -> HttpStatusCode.NotFound to "NOT_FOUND"
        is ServiceError.AlreadyExists -> HttpStatusCode.Conflict to "ALREADY_EXISTS"
        is ServiceError.ValidationError -> HttpStatusCode.BadRequest to "VALIDATION_ERROR"
        is ServiceError.InvalidOperation -> HttpStatusCode.BadRequest to "INVALID_OPERATION"
        is ServiceError.DatabaseError -> HttpStatusCode.InternalServerError to "DATABASE_ERROR"
        is ServiceError.UnknownError -> HttpStatusCode.InternalServerError to "UNKNOWN_ERROR"
    }

    respond(status, ErrorResponse(error = errorType, message = error.message))
}
