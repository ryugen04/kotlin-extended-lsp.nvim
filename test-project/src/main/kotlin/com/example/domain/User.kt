package com.example.domain

import kotlinx.serialization.Serializable
import java.time.LocalDateTime

/**
 * ユーザードメインモデル
 * LSPテスト項目:
 * - data classへのジャンプ
 * - sealed interfaceの実装へのジャンプ
 * - typeDefinitionのテスト
 */
@Serializable
data class User(
    val id: UserId,
    val email: Email,
    val name: UserName,
    val role: UserRole,
    val status: UserStatus,
    val createdAt: String,
    val updatedAt: String
) {
    companion object {
        fun create(
            email: String,
            name: String,
            role: UserRole = UserRole.USER
        ): User {
            val now = LocalDateTime.now().toString()
            return User(
                id = UserId.generate(),
                email = Email(email),
                name = UserName(name),
                role = role,
                status = UserStatus.ACTIVE,
                createdAt = now,
                updatedAt = now
            )
        }
    }

    fun isActive(): Boolean = status == UserStatus.ACTIVE
    fun isAdmin(): Boolean = role == UserRole.ADMIN
    fun canAccess(resource: Resource): Boolean = role.canAccess(resource)
}

/**
 * Value Object: ユーザーID
 */
@Serializable
@JvmInline
value class UserId(val value: Long) {
    companion object {
        private var counter = 0L
        fun generate(): UserId = UserId(++counter)
    }
}

/**
 * Value Object: メールアドレス
 */
@Serializable
@JvmInline
value class Email(val value: String) {
    init {
        require(value.contains("@")) { "Invalid email format: $value" }
    }
}

/**
 * Value Object: ユーザー名
 */
@Serializable
@JvmInline
value class UserName(val value: String) {
    init {
        require(value.isNotBlank()) { "User name cannot be blank" }
        require(value.length <= 100) { "User name too long: ${value.length}" }
    }
}

/**
 * ユーザーロール（権限管理）
 * LSPテスト: enumへのジャンプ、when式での補完
 */
enum class UserRole {
    ADMIN,
    MODERATOR,
    USER,
    GUEST;

    fun canAccess(resource: Resource): Boolean = when (this) {
        ADMIN -> true
        MODERATOR -> resource !is Resource.SystemConfig
        USER -> resource is Resource.PublicContent || resource is Resource.UserContent
        GUEST -> resource is Resource.PublicContent
    }
}

/**
 * ユーザーステータス
 * LSPテスト: sealed interfaceの実装へのジャンプ
 */
sealed interface UserStatus {
    val label: String

    data object ACTIVE : UserStatus {
        override val label = "Active"
    }

    data object INACTIVE : UserStatus {
        override val label = "Inactive"
    }

    data object SUSPENDED : UserStatus {
        override val label = "Suspended"
    }

    data class BANNED(val reason: String, val until: String?) : UserStatus {
        override val label = "Banned"
    }
}

/**
 * リソース種別（権限チェック用）
 * LSPテスト: sealed classの継承階層のジャンプ
 */
sealed interface Resource {
    data object PublicContent : Resource
    data class UserContent(val ownerId: UserId) : Resource
    data object SystemConfig : Resource
}
