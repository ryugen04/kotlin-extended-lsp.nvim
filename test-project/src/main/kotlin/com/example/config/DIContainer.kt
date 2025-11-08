package com.example.config

import com.example.repository.*
import com.example.service.*
import org.koin.core.module.dsl.bind
import org.koin.core.module.dsl.singleOf
import org.koin.dsl.module

/**
 * Koin DIコンテナ設定
 * LSPテスト項目:
 * - Koin DSLのナビゲーション
 * - インターフェースと実装のマッピング解決
 * - 型推論とバインディング
 */

/**
 * リポジトリモジュール
 * LSPテスト: モジュール定義内での型解決
 */
val repositoryModule = module {
    // UserRepository
    singleOf(::UserRepositoryImpl) { bind<UserRepository>() }

    // PostRepository
    singleOf(::PostRepositoryImpl) { bind<PostRepository>() }
}

/**
 * サービスモジュール
 * LSPテスト: 依存関係注入の型解決とコンストラクタ参照
 */
val serviceModule = module {
    // UserService - リポジトリを注入
    singleOf(::UserServiceImpl) { bind<UserService>() }

    // PostService - 複数のリポジトリを注入
    singleOf(::PostServiceImpl) { bind<PostService>() }
}

/**
 * 全モジュールリスト
 * LSPテスト: リスト要素へのジャンプ
 */
val allModules = listOf(
    repositoryModule,
    serviceModule
)
