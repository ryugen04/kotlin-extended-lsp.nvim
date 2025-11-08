package com.example.util

import arrow.core.Either
import arrow.core.raise.either
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * 汎用拡張関数コレクション
 * LSPテスト項目:
 * - 拡張関数の定義と参照検索
 * - ジェネリック型パラメータの解決
 * - インライン関数のナビゲーション
 */

/**
 * String拡張: 日付文字列のパース
 * LSPテスト: 拡張関数へのジャンプ、戻り値型の解決
 */
fun String.toLocalDateTime(): LocalDateTime =
    LocalDateTime.parse(this, DateTimeFormatter.ISO_DATE_TIME)

/**
 * String拡張: 安全な日付パース
 */
fun String.toLocalDateTimeOrNull(): LocalDateTime? =
    runCatching { toLocalDateTime() }.getOrNull()

/**
 * LocalDateTime拡張: フォーマット済み文字列
 */
fun LocalDateTime.toFormattedString(): String =
    this.format(DateTimeFormatter.ISO_DATE_TIME)

/**
 * List拡張: ページング
 * LSPテスト: ジェネリック型パラメータの型推論
 */
fun <T> List<T>.paginate(page: Int, pageSize: Int): List<T> {
    val offset = (page - 1) * pageSize
    return this.drop(offset).take(pageSize)
}

/**
 * List拡張: 安全なページング（Either）
 */
fun <T> List<T>.paginateSafely(page: Int, pageSize: Int): Either<String, List<T>> = either {
    if (page < 1) raise("Page must be greater than 0")
    if (pageSize < 1) raise("Page size must be greater than 0")
    if (pageSize > 1000) raise("Page size too large")

    paginate(page, pageSize)
}

/**
 * Collection拡張: 空チェックwith Either
 * LSPテスト: ジェネリック型の制約とレシーバー型
 */
fun <T> Collection<T>.notEmptyOrError(error: String): Either<String, Collection<T>> =
    if (this.isEmpty()) Either.Left(error) else Either.Right(this)

/**
 * Either拡張: エラーメッセージのマッピング
 * LSPテスト: 複雑なジェネリック型のナビゲーション
 */
fun <A, B> Either<A, B>.mapLeftToString(): Either<String, B> =
    this.mapLeft { it.toString() }

/**
 * インライン拡張関数: 時間計測
 * LSPテスト: インライン関数とラムダパラメータの型推論
 */
inline fun <T> measureTime(label: String, block: () -> T): T {
    val start = System.currentTimeMillis()
    return try {
        block()
    } finally {
        val elapsed = System.currentTimeMillis() - start
        println("[$label] took ${elapsed}ms")
    }
}

/**
 * suspend拡張関数: リトライロジック
 * LSPテスト: suspend関数のシグネチャヘルプ
 */
suspend fun <T> retry(
    times: Int = 3,
    delayMillis: Long = 1000,
    block: suspend () -> T
): T {
    repeat(times - 1) { attempt ->
        try {
            return block()
        } catch (e: Exception) {
            println("Attempt ${attempt + 1} failed: ${e.message}")
            kotlinx.coroutines.delay(delayMillis)
        }
    }
    return block() // Last attempt
}

/**
 * コンテキストレシーバーを使用した拡張関数の例
 * LSPテスト: context receiversの型解決
 */
context(StringBuilder)
fun String.appendWithPrefix(prefix: String) {
    append(prefix)
    append(this@appendWithPrefix)
}

/**
 * 型エイリアス
 * LSPテスト: 型エイリアスの定義と使用箇所のジャンプ
 */
typealias ValidationResult = Either<String, Unit>
typealias ServiceResult<T> = Either<com.example.service.ServiceError, T>

/**
 * 高階関数: バリデーションチェーンビルダー
 * LSPテスト: 高階関数の型推論とラムダレシーバー
 */
class ValidationBuilder<T> {
    private val validations = mutableListOf<(T) -> ValidationResult>()

    fun validate(check: (T) -> ValidationResult) {
        validations.add(check)
    }

    fun check(value: T): ValidationResult = either {
        validations.forEach { validation ->
            validation(value).bind()
        }
    }
}

/**
 * DSLビルダー関数
 * LSPテスト: DSLビルダーパターンのナビゲーション
 */
inline fun <T> buildValidation(
    builder: ValidationBuilder<T>.() -> Unit
): ValidationBuilder<T> {
    return ValidationBuilder<T>().apply(builder)
}

/**
 * スコープ関数の拡張
 * LSPテスト: スコープ関数とレシーバーの型解決
 */
inline fun <T> T.applyIf(condition: Boolean, block: T.() -> Unit): T {
    return if (condition) this.apply(block) else this
}

inline fun <T, R> T.letIf(condition: Boolean, block: (T) -> R): R? {
    return if (condition) block(this) else null
}
