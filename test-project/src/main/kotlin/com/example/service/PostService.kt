package com.example.service

import arrow.core.Either
import arrow.core.raise.either
import arrow.core.raise.ensure
import com.example.domain.*
import com.example.repository.PostRepository
import com.example.repository.UserRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import mu.KotlinLogging

/**
 * 投稿サービスインターフェース
 * LSPテスト項目:
 * - ジェネリック型パラメータの型定義ジャンプ
 * - デフォルト引数のシグネチャヘルプ
 */
interface PostService {
    suspend fun getPostById(id: PostId): Either<ServiceError, Post>
    suspend fun getPostsByAuthor(authorId: UserId): Either<ServiceError, List<Post>>
    suspend fun getPostsByTag(tag: Tag): Either<ServiceError, List<Post>>
    suspend fun createPost(
        authorId: UserId,
        title: String,
        content: String,
        tags: List<String> = emptyList()
    ): Either<ServiceError, Post>
    suspend fun updatePost(post: Post): Either<ServiceError, Post>
    suspend fun publishPost(id: PostId): Either<ServiceError, Post>
    suspend fun archivePost(id: PostId): Either<ServiceError, Post>
    suspend fun deletePost(id: PostId, requesterId: UserId): Either<ServiceError, Unit>
    suspend fun incrementViewCount(id: PostId): Either<ServiceError, Unit>
}

/**
 * 投稿サービス実装
 * LSPテスト項目:
 * - 複数のリポジトリ依存関係の解決
 * - Coroutines async/awaitのナビゲーション
 * - context receivers使用時の型解決
 */
class PostServiceImpl(
    private val postRepository: PostRepository,
    private val userRepository: UserRepository
) : PostService {

    private val logger = KotlinLogging.logger {}

    override suspend fun getPostById(id: PostId): Either<ServiceError, Post> = either {
        logger.debug { "Getting post by id: $id" }

        postRepository.findById(id)
            .mapLeft { it.toServiceError() }
            .bind()
            ?: raise(ServiceError.NotFound("Post not found: $id"))
    }

    override suspend fun getPostsByAuthor(authorId: UserId): Either<ServiceError, List<Post>> = either {
        logger.debug { "Getting posts by author: $authorId" }

        // ユーザーの存在確認
        userRepository.findById(authorId)
            .mapLeft { it.toServiceError() }
            .bind()
            ?: raise(ServiceError.NotFound("Author not found: $authorId"))

        postRepository.findByAuthor(authorId)
            .mapLeft { it.toServiceError() }
            .bind()
    }

    override suspend fun getPostsByTag(tag: Tag): Either<ServiceError, List<Post>> = either {
        logger.debug { "Getting posts by tag: ${tag.value}" }

        postRepository.findByTag(tag)
            .mapLeft { it.toServiceError() }
            .bind()
    }

    override suspend fun createPost(
        authorId: UserId,
        title: String,
        content: String,
        tags: List<String>
    ): Either<ServiceError, Post> = either {
        logger.info { "Creating post: $title" }

        // バリデーション
        validatePostTitle(title).bind()
        validatePostContent(content).bind()

        // 著者の存在確認と権限チェック
        val author = userRepository.findById(authorId)
            .mapLeft { it.toServiceError() }
            .bind()
            ?: raise(ServiceError.NotFound("Author not found: $authorId"))

        ensure(author.isActive()) {
            ServiceError.InvalidOperation("Author is not active")
        }

        // タグのバリデーション
        val validatedTags = tags.map { tagStr ->
            validateTag(tagStr).bind()
            Tag(tagStr)
        }

        // 投稿作成
        val post = Post(
            id = PostId.generate(),
            authorId = authorId,
            title = PostTitle(title),
            content = PostContent(content),
            tags = validatedTags,
            status = PostStatus.Draft,
            metadata = PostMetadata(),
            createdAt = java.time.LocalDateTime.now().toString(),
            updatedAt = java.time.LocalDateTime.now().toString()
        )

        postRepository.save(post)
            .mapLeft { it.toServiceError() }
            .bind()
            .also { logger.info { "Post created: ${it.id}" } }
    }

    override suspend fun updatePost(post: Post): Either<ServiceError, Post> = either {
        logger.info { "Updating post: ${post.id}" }

        // 存在確認
        val existing = getPostById(post.id).bind()

        // 著者の確認（著者のみ更新可能）
        ensure(existing.authorId == post.authorId) {
            ServiceError.InvalidOperation("Only author can update the post")
        }

        postRepository.update(post)
            .mapLeft { it.toServiceError() }
            .bind()
    }

    override suspend fun publishPost(id: PostId): Either<ServiceError, Post> = either {
        logger.info { "Publishing post: $id" }

        val post = getPostById(id).bind()

        ensure(post.isDraft()) {
            ServiceError.InvalidOperation("Only draft posts can be published")
        }

        val publishedPost = post.publish()
        updatePost(publishedPost).bind()
    }

    override suspend fun archivePost(id: PostId): Either<ServiceError, Post> = either {
        logger.info { "Archiving post: $id" }

        val post = getPostById(id).bind()

        ensure(post.isPublished()) {
            ServiceError.InvalidOperation("Only published posts can be archived")
        }

        val archivedPost = post.archive()
        updatePost(archivedPost).bind()
    }

    override suspend fun deletePost(id: PostId, requesterId: UserId): Either<ServiceError, Unit> = either {
        logger.warn { "Deleting post: $id by user: $requesterId" }

        // 並行処理の例: 投稿と要求者を同時取得
        // LSPテスト: coroutineScopeとasync/awaitのナビゲーション
        val (post, requester) = coroutineScope {
            val postDeferred = async { getPostById(id) }
            val requesterDeferred = async {
                userRepository.findById(requesterId)
                    .mapLeft { it.toServiceError() }
            }

            val p = postDeferred.await().bind()
            val r = requesterDeferred.await().bind()
                ?: raise(ServiceError.NotFound("Requester not found: $requesterId"))

            Pair(p, r)
        }

        // 削除権限チェック
        ensure(requester.canAccess(Resource.UserContent(post.authorId)) || requester.isAdmin()) {
            ServiceError.InvalidOperation("User does not have permission to delete this post")
        }

        postRepository.delete(id)
            .mapLeft { it.toServiceError() }
            .bind()
    }

    override suspend fun incrementViewCount(id: PostId): Either<ServiceError, Unit> = either {
        logger.debug { "Incrementing view count: $id" }

        postRepository.incrementViewCount(id)
            .mapLeft { it.toServiceError() }
            .bind()
    }

    // プライベートバリデーション関数
    private fun validatePostTitle(title: String): Either<ServiceError, Unit> = either {
        ensure(title.isNotBlank()) {
            ServiceError.ValidationError("Title cannot be blank")
        }
        ensure(title.length <= 200) {
            ServiceError.ValidationError("Title too long")
        }
    }

    private fun validatePostContent(content: String): Either<ServiceError, Unit> = either {
        ensure(content.isNotBlank()) {
            ServiceError.ValidationError("Content cannot be blank")
        }
    }

    private fun validateTag(tag: String): Either<ServiceError, Unit> = either {
        ensure(tag.matches(Regex("^[a-z0-9-]+$"))) {
            ServiceError.ValidationError("Tag must contain only lowercase letters, numbers, and hyphens")
        }
    }
}
