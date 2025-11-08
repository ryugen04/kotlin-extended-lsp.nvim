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
 * 投稿リポジトリインターフェース
 * LSPテスト項目:
 * - interfaceから実装へのジャンプ
 * - 複数の実装メソッドへのナビゲーション
 */
interface PostRepository {
    suspend fun findById(id: PostId): Either<RepositoryError, Post?>
    suspend fun findByAuthor(authorId: UserId): Either<RepositoryError, List<Post>>
    suspend fun findByStatus(status: PostStatus): Either<RepositoryError, List<Post>>
    suspend fun findByTag(tag: Tag): Either<RepositoryError, List<Post>>
    suspend fun save(post: Post): Either<RepositoryError, Post>
    suspend fun update(post: Post): Either<RepositoryError, Post>
    suspend fun delete(id: PostId): Either<RepositoryError, Unit>
    suspend fun incrementViewCount(id: PostId): Either<RepositoryError, Unit>
}

/**
 * Exposedを使用した投稿リポジトリ実装
 * LSPテスト項目:
 * - interface実装メソッドへのジャンプ
 * - データベーステーブル定義へのジャンプ
 * - 拡張関数へのジャンプ
 */
class PostRepositoryImpl : PostRepository {

    object Posts : LongIdTable("posts") {
        val authorId = long("author_id")
        val title = varchar("title", 200)
        val content = text("content")
        val tags = text("tags") // JSON array as text
        val status = varchar("status", 50)
        val viewCount = long("view_count").default(0)
        val likeCount = long("like_count").default(0)
        val commentCount = long("comment_count").default(0)
        val createdAt = datetime("created_at")
        val updatedAt = datetime("updated_at")
    }

    override suspend fun findById(id: PostId): Either<RepositoryError, Post?> =
        Either.catch {
            transaction {
                Posts.select { Posts.id eq id.value }
                    .map { it.toPost() }
                    .singleOrNull()
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun findByAuthor(authorId: UserId): Either<RepositoryError, List<Post>> =
        Either.catch {
            transaction {
                Posts.select { Posts.authorId eq authorId.value }
                    .orderBy(Posts.createdAt to SortOrder.DESC)
                    .map { it.toPost() }
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun findByStatus(status: PostStatus): Either<RepositoryError, List<Post>> =
        Either.catch {
            transaction {
                val statusStr = when (status) {
                    is PostStatus.Draft -> "Draft"
                    is PostStatus.Published -> "Published"
                    is PostStatus.Archived -> "Archived"
                    is PostStatus.Scheduled -> "Scheduled"
                }
                Posts.select { Posts.status eq statusStr }
                    .orderBy(Posts.createdAt to SortOrder.DESC)
                    .map { it.toPost() }
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun findByTag(tag: Tag): Either<RepositoryError, List<Post>> =
        Either.catch {
            transaction {
                // Simple contains search in JSON array
                Posts.select { Posts.tags like "%${tag.value}%" }
                    .orderBy(Posts.createdAt to SortOrder.DESC)
                    .map { it.toPost() }
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun save(post: Post): Either<RepositoryError, Post> =
        Either.catch {
            transaction {
                Posts.insert {
                    it[authorId] = post.authorId.value
                    it[title] = post.title.value
                    it[content] = post.content.value
                    it[tags] = post.tags.joinToString(",") { tag -> tag.value }
                    it[status] = post.status.toStatusString()
                    it[viewCount] = post.metadata.viewCount
                    it[likeCount] = post.metadata.likeCount
                    it[commentCount] = post.metadata.commentCount
                    it[createdAt] = LocalDateTime.parse(post.createdAt)
                    it[updatedAt] = LocalDateTime.parse(post.updatedAt)
                }
                post
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun update(post: Post): Either<RepositoryError, Post> =
        Either.catch {
            transaction {
                Posts.update({ Posts.id eq post.id.value }) {
                    it[title] = post.title.value
                    it[content] = post.content.value
                    it[tags] = post.tags.joinToString(",") { tag -> tag.value }
                    it[status] = post.status.toStatusString()
                    it[viewCount] = post.metadata.viewCount
                    it[likeCount] = post.metadata.likeCount
                    it[commentCount] = post.metadata.commentCount
                    it[updatedAt] = LocalDateTime.parse(post.updatedAt)
                }
                post
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun delete(id: PostId): Either<RepositoryError, Unit> =
        Either.catch {
            transaction {
                Posts.deleteWhere { Posts.id eq id.value }
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    override suspend fun incrementViewCount(id: PostId): Either<RepositoryError, Unit> =
        Either.catch {
            transaction {
                Posts.update({ Posts.id eq id.value }) {
                    it[viewCount] = viewCount + 1
                }
            }
        }.mapLeft { RepositoryError.DatabaseError(it.message ?: "Unknown error") }

    private fun ResultRow.toPost(): Post = Post(
        id = PostId(this[Posts.id].value),
        authorId = UserId(this[Posts.authorId]),
        title = PostTitle(this[Posts.title]),
        content = PostContent(this[Posts.content]),
        tags = this[Posts.tags].split(",").map { Tag(it.trim()) },
        status = this[Posts.status].toPostStatus(),
        metadata = PostMetadata(
            viewCount = this[Posts.viewCount],
            likeCount = this[Posts.likeCount],
            commentCount = this[Posts.commentCount]
        ),
        createdAt = this[Posts.createdAt].toString(),
        updatedAt = this[Posts.updatedAt].toString()
    )
}

// 拡張関数: PostStatusを文字列に変換
// LSPテスト: 拡張関数へのジャンプ、参照検索
private fun PostStatus.toStatusString(): String = when (this) {
    is PostStatus.Draft -> "Draft"
    is PostStatus.Published -> "Published"
    is PostStatus.Archived -> "Archived"
    is PostStatus.Scheduled -> "Scheduled:${this.publishAt}"
}

// 拡張関数: 文字列をPostStatusに変換
private fun String.toPostStatus(): PostStatus = when {
    this == "Draft" -> PostStatus.Draft
    this == "Published" -> PostStatus.Published
    this == "Archived" -> PostStatus.Archived
    this.startsWith("Scheduled:") -> PostStatus.Scheduled(this.substringAfter("Scheduled:"))
    else -> PostStatus.Draft
}
