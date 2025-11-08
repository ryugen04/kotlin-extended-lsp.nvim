package com.example.service

import arrow.core.Either
import arrow.core.raise.either
import arrow.core.raise.ensure
import com.example.domain.*
import com.example.repository.UserRepository
import com.example.repository.RepositoryError
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import mu.KotlinLogging

/**
 * ユーザーサービス
 * LSPテスト項目:
 * - インターフェース定義から実装へのジャンプ
 * - suspend関数のシグネチャヘルプ
 * - Arrow Either型の型定義ジャンプ
 * - Coroutinesコンテキストレシーバーの解決
 */
interface UserService {
    suspend fun getUserById(id: UserId): Either<ServiceError, User>
    suspend fun getUserByEmail(email: Email): Either<ServiceError, User>
    suspend fun createUser(email: String, name: String, role: UserRole): Either<ServiceError, User>
    suspend fun updateUser(user: User): Either<ServiceError, User>
    suspend fun deleteUser(id: UserId): Either<ServiceError, Unit>
    suspend fun listUsers(limit: Int = 100, offset: Int = 0): Either<ServiceError, List<User>>
    suspend fun activateUser(id: UserId): Either<ServiceError, User>
    suspend fun suspendUser(id: UserId, reason: String): Either<ServiceError, User>
}

/**
 * ユーザーサービス実装
 * LSPテスト項目:
 * - コンストラクタインジェクションの型解決
 * - ロガーの型定義とメソッド補完
 * - 複雑なEither型チェーンのナビゲーション
 */
class UserServiceImpl(
    private val userRepository: UserRepository
) : UserService {

    private val logger = KotlinLogging.logger {}

    override suspend fun getUserById(id: UserId): Either<ServiceError, User> = either {
        logger.debug { "Getting user by id: $id" }

        withContext(Dispatchers.IO) {
            userRepository.findById(id)
        }.mapLeft { it.toServiceError() }
            .bind()
            ?.let { user ->
                logger.info { "User found: ${user.email}" }
                user
            } ?: run {
                logger.warn { "User not found: $id" }
                raise(ServiceError.NotFound("User not found: $id"))
            }
    }

    override suspend fun getUserByEmail(email: Email): Either<ServiceError, User> = either {
        logger.debug { "Getting user by email: ${email.value}" }

        withContext(Dispatchers.IO) {
            userRepository.findByEmail(email)
        }.mapLeft { it.toServiceError() }
            .bind()
            ?.let { user ->
                logger.info { "User found: ${user.id}" }
                user
            } ?: raise(ServiceError.NotFound("User not found: ${email.value}"))
    }

    override suspend fun createUser(
        email: String,
        name: String,
        role: UserRole
    ): Either<ServiceError, User> = either {
        logger.info { "Creating user: $email" }

        // バリデーション
        validateEmail(email).bind()
        validateUserName(name).bind()

        val emailVO = Email(email)

        // 重複チェック
        val exists = withContext(Dispatchers.IO) {
            userRepository.existsByEmail(emailVO)
        }.mapLeft { it.toServiceError() }.bind()

        ensure(!exists) { ServiceError.AlreadyExists("User with email $email already exists") }

        // ユーザー作成
        val user = User.create(email, name, role)

        withContext(Dispatchers.IO) {
            userRepository.save(user)
        }.mapLeft { it.toServiceError() }
            .bind()
            .also { logger.info { "User created: ${it.id}" } }
    }

    override suspend fun updateUser(user: User): Either<ServiceError, User> = either {
        logger.info { "Updating user: ${user.id}" }

        // 存在確認
        getUserById(user.id).bind()

        withContext(Dispatchers.IO) {
            userRepository.update(user)
        }.mapLeft { it.toServiceError() }
            .bind()
            .also { logger.info { "User updated: ${it.id}" } }
    }

    override suspend fun deleteUser(id: UserId): Either<ServiceError, Unit> = either {
        logger.info { "Deleting user: $id" }

        // 存在確認
        getUserById(id).bind()

        withContext(Dispatchers.IO) {
            userRepository.delete(id)
        }.mapLeft { it.toServiceError() }
            .bind()
            .also { logger.info { "User deleted: $id" } }
    }

    override suspend fun listUsers(limit: Int, offset: Int): Either<ServiceError, List<User>> = either {
        logger.debug { "Listing users: limit=$limit, offset=$offset" }

        ensure(limit > 0 && limit <= 1000) {
            ServiceError.ValidationError("Limit must be between 1 and 1000")
        }
        ensure(offset >= 0) {
            ServiceError.ValidationError("Offset must be non-negative")
        }

        withContext(Dispatchers.IO) {
            userRepository.findAll(limit, offset)
        }.mapLeft { it.toServiceError() }
            .bind()
            .also { logger.debug { "Found ${it.size} users" } }
    }

    override suspend fun activateUser(id: UserId): Either<ServiceError, User> = either {
        logger.info { "Activating user: $id" }

        val user = getUserById(id).bind()
        val updatedUser = user.copy(status = UserStatus.ACTIVE)

        updateUser(updatedUser).bind()
    }

    override suspend fun suspendUser(id: UserId, reason: String): Either<ServiceError, User> = either {
        logger.warn { "Suspending user: $id, reason: $reason" }

        val user = getUserById(id).bind()

        ensure(user.status == UserStatus.ACTIVE) {
            ServiceError.InvalidOperation("Cannot suspend non-active user")
        }

        val updatedUser = user.copy(status = UserStatus.SUSPENDED)
        updateUser(updatedUser).bind()
    }

    // プライベートヘルパー関数
    // LSPテスト: プライベート関数へのジャンプ、参照検索
    private fun validateEmail(email: String): Either<ServiceError, Unit> = either {
        ensure(email.isNotBlank()) {
            ServiceError.ValidationError("Email cannot be blank")
        }
        ensure(email.contains("@")) {
            ServiceError.ValidationError("Invalid email format")
        }
        ensure(email.length <= 255) {
            ServiceError.ValidationError("Email too long")
        }
    }

    private fun validateUserName(name: String): Either<ServiceError, Unit> = either {
        ensure(name.isNotBlank()) {
            ServiceError.ValidationError("Name cannot be blank")
        }
        ensure(name.length <= 100) {
            ServiceError.ValidationError("Name too long")
        }
    }
}

/**
 * サービスエラー型
 * LSPテスト項目:
 * - sealed interfaceの階層ナビゲーション
 * - when式での網羅性チェック
 */
sealed interface ServiceError {
    val message: String

    data class NotFound(override val message: String) : ServiceError
    data class AlreadyExists(override val message: String) : ServiceError
    data class ValidationError(override val message: String) : ServiceError
    data class InvalidOperation(override val message: String) : ServiceError
    data class DatabaseError(override val message: String) : ServiceError
    data class UnknownError(override val message: String, val cause: Throwable? = null) : ServiceError
}

// 拡張関数: RepositoryErrorをServiceErrorに変換
// LSPテスト: 拡張関数の定義と使用箇所のジャンプ
private fun RepositoryError.toServiceError(): ServiceError = when (this) {
    is RepositoryError.NotFound -> ServiceError.NotFound(this.id)
    is RepositoryError.DuplicateKey -> ServiceError.AlreadyExists("Duplicate key: ${this.key}")
    is RepositoryError.DatabaseError -> ServiceError.DatabaseError(this.message)
    is RepositoryError.ConnectionError -> ServiceError.DatabaseError("Database connection error")
}
