package com.example.repository

import arrow.core.Either
import com.example.domain.*
import org.jetbrains.exposed.dao.id.LongIdTable
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.javatime.datetime
import org.jetbrains.exposed.sql.transactions.transaction
import java.time.LocalDateTime

/**
 * ユーザーリポジトリインターフェース
 * LSPテスト項目:
 * - interfaceから実装へのジャンプ (textDocument/implementation)
 * - ドメインモデルへのジャンプ
 */
interface UserRepository {
    suspend fun findById(id: UserId): Either<RepositoryError, User?>
    suspend fun findByEmail(email: Email): Either<RepositoryError, User?>
    suspend fun findAll(limit: Int = 100, offset: Int = 0): Either<RepositoryError, List<User>>
    suspend fun save(user: User): Either<RepositoryError, User>
    suspend fun update(user: User): Either<RepositoryError, User>
    suspend fun delete(id: UserId): Either<RepositoryError, Unit>
    suspend fun existsByEmail(email: Email): Either<RepositoryError, Boolean>
}

/**
 * Exposedを使用したユーザーリポジトリ実装
 * LSPテスト項目:
 * - interface実装のジャンプ
 * - Exposed APIへのジャンプ（JAR内）
 * - Table定義へのジャンプ
 */
class UserRepositoryImpl : UserRepository {

    object Users : LongIdTable("users") {
        val email = varchar("email", 255).uniqueIndex()
        val name = varchar("name", 100)
        val role = varchar("role", 50)
        val status = varchar("status", 50)
        val createdAt = datetime("created_at")
        val updatedAt = datetime("updated_at")
    }

    override suspend fun findById(id: UserId): Either<RepositoryError, User?> =
        Either.catch {
            transaction {
                Users.select { Users.id eq id.value }
                    .map { it.toUser() }
                    .singleOrNull()
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun findByEmail(email: Email): Either<RepositoryError, User?> =
        Either.catch {
            transaction {
                Users.select { Users.email eq email.value }
                    .map { it.toUser() }
                    .singleOrNull()
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun findAll(limit: Int, offset: Int): Either<RepositoryError, List<User>> =
        Either.catch {
            transaction {
                Users.selectAll()
                    .limit(limit, offset.toLong())
                    .map { it.toUser() }
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun save(user: User): Either<RepositoryError, User> =
        Either.catch {
            transaction {
                Users.insert {
                    it[email] = user.email.value
                    it[name] = user.name.value
                    it[role] = user.role.name
                    it[status] = user.status.label
                    it[createdAt] = LocalDateTime.parse(user.createdAt)
                    it[updatedAt] = LocalDateTime.parse(user.updatedAt)
                }
                user
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun update(user: User): Either<RepositoryError, User> =
        Either.catch {
            transaction {
                Users.update({ Users.id eq user.id.value }) {
                    it[email] = user.email.value
                    it[name] = user.name.value
                    it[role] = user.role.name
                    it[status] = user.status.label
                    it[updatedAt] = LocalDateTime.parse(user.updatedAt)
                }
                user
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun delete(id: UserId): Either<RepositoryError, Unit> =
        Either.catch {
            transaction {
                Users.deleteWhere { Users.id eq id.value }
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun existsByEmail(email: Email): Either<RepositoryError, Boolean> =
        Either.catch {
            transaction {
                Users.select { Users.email eq email.value }.count() > 0
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    private fun ResultRow.toUser(): User = User(
        id = UserId(this[Users.id].value),
        email = Email(this[Users.email]),
        name = UserName(this[Users.name]),
        role = UserRole.valueOf(this[Users.role]),
        status = when (this[Users.status]) {
            "Active" -> UserStatus.ACTIVE
            "Inactive" -> UserStatus.INACTIVE
            "Suspended" -> UserStatus.SUSPENDED
            else -> UserStatus.BANNED("Unknown", null)
        },
        createdAt = this[Users.createdAt].toString(),
        updatedAt = this[Users.updatedAt].toString()
    )
}

/**
 * リポジトリエラー型
 * LSPテスト: sealed interfaceのエラーハンドリング
 */
sealed interface RepositoryError {
    data class DatabaseError(val message: String) : RepositoryError
    data class NotFound(val id: String) : RepositoryError
    data class DuplicateKey(val key: String) : RepositoryError
    data object ConnectionError : RepositoryError
}
