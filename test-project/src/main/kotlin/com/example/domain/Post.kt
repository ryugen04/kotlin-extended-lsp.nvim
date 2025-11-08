package com.example.domain

import kotlinx.serialization.Serializable

/**
 * 投稿ドメインモデル
 * LSPテスト項目:
 * - 他のドメインモデル（User）へのジャンプ
 * - ネストされたdata classへのジャンプ
 */
@Serializable
data class Post(
    val id: PostId,
    val authorId: UserId,
    val title: PostTitle,
    val content: PostContent,
    val tags: List<Tag>,
    val status: PostStatus,
    val metadata: PostMetadata,
    val createdAt: String,
    val updatedAt: String
) {
    fun isPublished(): Boolean = status is PostStatus.Published
    fun isDraft(): Boolean = status is PostStatus.Draft

    fun canEditBy(user: User): Boolean = when {
        user.isAdmin() -> true
        user.id == authorId -> true
        else -> false
    }

    fun publish(): Post = copy(status = PostStatus.Published)
    fun archive(): Post = copy(status = PostStatus.Archived)
}

/**
 * Value Object: 投稿ID
 */
@Serializable
@JvmInline
value class PostId(val value: Long) {
    companion object {
        private var counter = 0L
        fun generate(): PostId = PostId(++counter)
    }
}

/**
 * Value Object: 投稿タイトル
 */
@Serializable
@JvmInline
value class PostTitle(val value: String) {
    init {
        require(value.isNotBlank()) { "Post title cannot be blank" }
        require(value.length <= 200) { "Post title too long" }
    }
}

/**
 * Value Object: 投稿内容
 */
@Serializable
@JvmInline
value class PostContent(val value: String) {
    init {
        require(value.isNotBlank()) { "Post content cannot be blank" }
    }

    fun preview(maxLength: Int = 100): String =
        if (value.length <= maxLength) value
        else value.take(maxLength) + "..."
}

/**
 * Value Object: タグ
 */
@Serializable
@JvmInline
value class Tag(val value: String) {
    init {
        require(value.matches(Regex("^[a-z0-9-]+$"))) {
            "Tag must contain only lowercase letters, numbers, and hyphens"
        }
    }
}

/**
 * 投稿ステータス
 * LSPテスト: sealed classの階層構造
 */
sealed interface PostStatus {
    data object Draft : PostStatus
    data object Published : PostStatus
    data object Archived : PostStatus
    data class Scheduled(val publishAt: String) : PostStatus
}

/**
 * 投稿メタデータ
 * LSPテスト: ネストされたdata class
 */
@Serializable
data class PostMetadata(
    val viewCount: Long = 0,
    val likeCount: Long = 0,
    val commentCount: Long = 0,
    val shareCount: Long = 0,
    val seo: SeoMetadata? = null
) {
    @Serializable
    data class SeoMetadata(
        val metaTitle: String?,
        val metaDescription: String?,
        val keywords: List<String>
    )

    fun incrementView(): PostMetadata = copy(viewCount = viewCount + 1)
    fun incrementLike(): PostMetadata = copy(likeCount = likeCount + 1)
}
