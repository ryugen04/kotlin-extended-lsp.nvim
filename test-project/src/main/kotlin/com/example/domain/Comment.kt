package com.example.domain

import kotlinx.serialization.Serializable

/**
 * コメントドメインモデル
 * LSPテスト項目:
 * - 複数ドメインモデルへの参照のジャンプ
 * - 再帰的なデータ構造（返信）のナビゲーション
 */
@Serializable
data class Comment(
    val id: CommentId,
    val postId: PostId,
    val authorId: UserId,
    val content: CommentContent,
    val parentId: CommentId? = null,
    val status: CommentStatus,
    val createdAt: String,
    val updatedAt: String
) {
    fun isReply(): Boolean = parentId != null
    fun isApproved(): Boolean = status is CommentStatus.Approved

    fun canEditBy(user: User): Boolean = when {
        user.isAdmin() -> true
        user.id == authorId -> true
        else -> false
    }

    fun canDeleteBy(user: User): Boolean = when {
        user.isAdmin() -> true
        user.id == authorId -> true
        else -> false
    }
}

/**
 * Value Object: コメントID
 */
@Serializable
@JvmInline
value class CommentId(val value: Long) {
    companion object {
        private var counter = 0L
        fun generate(): CommentId = CommentId(++counter)
    }
}

/**
 * Value Object: コメント内容
 */
@Serializable
@JvmInline
value class CommentContent(val value: String) {
    init {
        require(value.isNotBlank()) { "Comment content cannot be blank" }
        require(value.length <= 1000) { "Comment too long" }
    }
}

/**
 * コメントステータス
 * LSPテスト: sealed interfaceの複雑な階層
 */
sealed interface CommentStatus {
    data object Pending : CommentStatus
    data object Approved : CommentStatus
    data object Rejected : CommentStatus
    data class Flagged(val reason: FlagReason, val flaggedBy: UserId) : CommentStatus {
        enum class FlagReason {
            SPAM,
            INAPPROPRIATE,
            HARASSMENT,
            OTHER
        }
    }
}
