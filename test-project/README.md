# kotlin-extended-lsp.nvim テストプロジェクト

このプロジェクトは、kotlin-extended-lsp.nvimプラグインの全LSP機能を網羅的にテストするための実務的なサーバーサイドKotlinアプリケーションです。

## プロジェクト構成

```
src/main/kotlin/com/example/
├── domain/           # ドメインモデル
│   ├── User.kt      # ユーザードメイン（sealed interface, value class, enum）
│   ├── Post.kt      # 投稿ドメイン（data class, nested types）
│   └── Comment.kt   # コメントドメイン（再帰的構造）
├── repository/      # リポジトリ層（Exposed ORM）
│   ├── UserRepository.kt    # インターフェースと実装
│   └── PostRepository.kt    # 拡張関数使用例
├── service/         # サービス層（ビジネスロジック）
│   ├── UserService.kt       # Arrow Either、Coroutines使用
│   └── PostService.kt       # 並行処理、複雑な型推論
├── api/             # API層（Ktor）
│   └── UserRoutes.kt        # RESTful API、拡張関数
├── util/            # ユーティリティ
│   └── Extensions.kt        # 拡張関数、ジェネリクス、DSL
├── config/          # 設定
│   └── DIContainer.kt       # Koin DI設定
└── Application.kt   # メインエントリーポイント

src/test/kotlin/com/example/
└── service/
    └── UserServiceTest.kt   # Kotestテスト例
```

## LSP機能テストマトリクス

このプロジェクトでテストできるLSP機能の一覧です。各機能について、どのファイルのどの部分でテストできるかを示しています。

### 1. ナビゲーション機能

#### `gd` - 定義へジャンプ (textDocument/definition)

| テスト内容 | ファイル | 行 | 説明 |
|-----------|---------|-----|------|
| Value classへのジャンプ | `domain/User.kt` | 12-15 | `UserId`、`Email`、`UserName` |
| Sealed interfaceへのジャンプ | `domain/User.kt` | 54-69 | `UserStatus`の各実装 |
| Data classへのジャンプ | `domain/Post.kt` | 13-25 | `Post`のプロパティ |
| Enumへのジャンプ | `domain/User.kt` | 43-52 | `UserRole` |
| 関数定義へのジャンプ | `service/UserService.kt` | 30-50 | `getUserById` |
| 拡張関数へのジャンプ | `util/Extensions.kt` | 19-21 | `toLocalDateTime` |
| プロパティへのジャンプ | `domain/User.kt` | 10-17 | `User`のプロパティ |

#### `gi` - 実装へジャンプ (textDocument/implementation)

| テスト内容 | ファイル | 行 | 説明 |
|-----------|---------|-----|------|
| Interfaceから実装へ | `repository/UserRepository.kt` | 17 → 33 | `UserRepository` → `UserRepositoryImpl` |
| Interfaceメソッドから実装へ | `service/UserService.kt` | 22 → 40 | `getUserById`インターフェース → 実装 |
| Sealed interfaceの実装へ | `domain/User.kt` | 54 → 56-69 | `UserStatus` → 各実装 |
| Abstract classから実装へ | `repository/PostRepository.kt` | 17 → 33 | `PostRepository` → 実装 |

#### `gy` - 型定義へジャンプ (textDocument/typeDefinition)

| テスト内容 | ファイル | 行 | 説明 |
|-----------|---------|-----|------|
| 変数の型定義へ | `service/UserService.kt` | 35 | `userRepository`の型 |
| 戻り値の型定義へ | `service/UserService.kt` | 30 | `Either<ServiceError, User>` |
| ジェネリック型パラメータへ | `util/Extensions.kt` | 40 | `List<T>`の`T` |
| プロパティの型定義へ | `domain/User.kt` | 12 | `UserId`型 |
| Lambda戻り値の型へ | `util/Extensions.kt` | 98 | `ValidationResult` |

#### `gD` - 宣言へジャンプ (textDocument/declaration)

| テスト内容 | ファイル | 行 | 説明 |
|-----------|---------|-----|------|
| クラス宣言へ | `domain/User.kt` | 11 | `User` data class |
| インターフェース宣言へ | `service/UserService.kt` | 17 | `UserService` interface |
| 型エイリアス宣言へ | `util/Extensions.kt` | 115-116 | `ValidationResult` |

#### `gr` - 参照検索 (textDocument/references)

| テスト内容 | ファイル | 説明 |
|-----------|---------|------|
| クラスの使用箇所検索 | `domain/User.kt` → 全ファイル | `User`の使用箇所 |
| 関数の使用箇所検索 | `service/UserService.kt` | `getUserById`の呼び出し箇所 |
| 拡張関数の使用箇所 | `util/Extensions.kt` | `toLocalDateTime`の使用箇所 |
| インターフェースの実装検索 | `repository/UserRepository.kt` | `UserRepository`の実装クラス |

### 2. ドキュメント表示機能

#### `K` - ホバードキュメント (textDocument/hover)

| テスト内容 | ファイル | 行 | 説明 |
|-----------|---------|-----|------|
| 関数のドキュメント | `service/UserService.kt` | 30 | `getUserById`のKDoc |
| クラスのドキュメント | `domain/User.kt` | 11 | `User`のKDoc |
| パラメータの型情報 | `service/UserService.kt` | 65 | `createUser`のパラメータ |
| 拡張関数の情報 | `util/Extensions.kt` | 19 | `toLocalDateTime` |
| JAR内クラスの情報 | `service/UserService.kt` | 44 | `withContext`（Coroutines） |

#### `<C-k>` - シグネチャヘルプ (textDocument/signatureHelp)

| テスト内容 | ファイル | 行 | 説明 |
|-----------|---------|-----|------|
| 関数呼び出しのシグネチャ | `service/UserService.kt` | 65 | `createUser()` |
| デフォルト引数の表示 | `service/PostService.kt` | 51 | `createPost()` |
| ジェネリック関数のシグネチャ | `util/Extensions.kt` | 40 | `paginate<T>()` |
| 拡張関数のシグネチャ | `util/Extensions.kt` | 64 | `notEmptyOrError()` |
| Suspend関数のシグネチャ | `service/UserService.kt` | 112 | `updateUser()` |

### 3. 編集機能

#### `<leader>rn` - シンボルリネーム (textDocument/rename)

| テスト内容 | ファイル | 説明 |
|-----------|---------|------|
| ローカル変数のリネーム | `service/UserService.kt` | 関数内ローカル変数 |
| 関数のリネーム | `service/UserService.kt` | `getUserById` |
| クラスのリネーム | `domain/User.kt` | `User` |
| プロパティのリネーム | `domain/User.kt` | `email`プロパティ |
| パラメータのリネーム | `service/UserService.kt` | 関数パラメータ |

#### `<leader>ca` - コードアクション (textDocument/codeAction)

| テスト内容 | ファイル | 説明 |
|-----------|---------|------|
| Import追加 | 任意のファイル | 未インポートのクラス使用時 |
| 実装メソッド追加 | `repository/UserRepository.kt` | インターフェース実装時 |
| クイックフィックス | 任意のファイル | エラー箇所で実行 |

#### `<leader>f` - フォーマット (textDocument/formatting)

| テスト内容 | ファイル | 説明 |
|-----------|---------|------|
| ファイル全体フォーマット | 任意のファイル | ノーマルモード |
| 選択範囲フォーマット | 任意のファイル | ビジュアルモード |

### 4. 診断機能

#### `[d` / `]d` - 診断移動 (vim.diagnostic.goto_prev/next)

| テスト内容 | 説明 |
|-----------|------|
| エラー間の移動 | コンパイルエラーがある場合 |
| 警告間の移動 | 未使用変数など |

#### `<leader>e` - 診断表示 (vim.diagnostic.open_float)

| テスト内容 | 説明 |
|-----------|------|
| エラー詳細表示 | カーソル位置のエラーメッセージ |
| 警告詳細表示 | 警告メッセージとコード |

#### `<leader>q` - ロケーションリスト (vim.diagnostic.setloclist)

| テスト内容 | 説明 |
|-----------|------|
| 全診断の一覧表示 | ファイル内の全エラー・警告 |

## 特殊なLSPテストケース

### JAR/クラスファイルへのジャンプ（デコンパイル）

以下の箇所でJAR内のKotlin標準ライブラリやサードパーティライブラリへのジャンプをテストできます:

| テスト内容 | ファイル | 行 | ジャンプ先 |
|-----------|---------|-----|-----------|
| Kotlin stdlib | `service/UserService.kt` | 44 | `withContext`（kotlinx-coroutines） |
| Arrow | `service/UserService.kt` | 30 | `Either`（arrow-core） |
| Exposed | `repository/UserRepository.kt` | 33 | `LongIdTable`（exposed-core） |
| Ktor | `api/UserRoutes.kt` | 17 | `Route`（ktor-server-core） |
| Koin | `config/DIContainer.kt` | 17 | `module`（koin-core） |
| Kotest | `test/.../UserServiceTest.kt` | 13 | `DescribeSpec`（kotest-core） |

### 複雑な型推論テスト

| テスト内容 | ファイル | 行 | 説明 |
|-----------|---------|-----|------|
| Either型チェーン | `service/UserService.kt` | 40-50 | `mapLeft().bind()` |
| Coroutines scope | `service/PostService.kt` | 147-158 | `coroutineScope { async/await }` |
| ジェネリック型推論 | `util/Extensions.kt` | 40-45 | `List<T>.paginate()` |
| DSLビルダー | `util/Extensions.kt` | 120-125 | `buildValidation<T>` |
| Context receivers | `util/Extensions.kt` | 95-99 | `context(StringBuilder)` |
| 拡張関数レシーバー | `repository/PostRepository.kt` | 164-175 | `PostStatus.toStatusString()` |

### when式の網羅性チェック

| テスト内容 | ファイル | 行 | 説明 |
|-----------|---------|-----|------|
| Sealed interface | `api/UserRoutes.kt` | 138-145 | `ServiceError`の全パターン |
| Enum | `domain/User.kt` | 48-52 | `UserRole`の全パターン |
| Sealed class | `repository/PostRepository.kt` | 78-83 | `PostStatus`の全パターン |

## テスト手順

### 1. プロジェクトのビルド

```bash
cd test-project
./gradlew build
```

### 2. Neovimでプロジェクトを開く

```bash
nvim src/main/kotlin/com/example/domain/User.kt
```

### 3. LSP機能の動作確認

各機能について、上記のマトリクスに従ってテストしてください。

#### ナビゲーション機能のテスト例

1. `domain/User.kt`を開く
2. `User`クラスの`email`プロパティ（12行目）にカーソルを移動
3. `gd`を押す → `Email`のvalue class定義（25行目）にジャンプ
4. `Email`の使用箇所を確認するため`gr`を押す → 参照一覧が表示
5. `K`を押す → `Email`のドキュメントが表示

#### 実装へのジャンプテスト例

1. `repository/UserRepository.kt`を開く
2. `UserRepository`インターフェース名（17行目）にカーソルを移動
3. `gi`を押す → `UserRepositoryImpl`の実装（33行目）にジャンプ

#### JAR内ジャンプテスト例

1. `service/UserService.kt`を開く
2. `withContext`（44行目）にカーソルを移動
3. `gd`を押す → kotlinx-coroutines JARがデコンパイルされて表示

#### コードアクション・リネームテスト例

1. `service/UserService.kt`を開く
2. `getUserById`関数名にカーソルを移動
3. `<leader>rn`を押す → リネームプロンプトが表示
4. 新しい名前を入力 → すべての使用箇所が一括変更

## トラブルシューティング

### kotlin-lspが起動しない

```bash
# kotlin-lspのインストール確認
which kotlin-lsp

# Neovimでヘルスチェック
:checkhealth kotlin-extended-lsp
```

### LSP機能が動作しない

```vim
" LSPログレベルをdebugに変更
:KotlinToggleLog debug

" LSPサーバーの機能確認
:KotlinLspCapabilities
```

### ビルドエラー

```bash
# 依存関係の再ダウンロード
./gradlew clean build --refresh-dependencies
```

## 期待される動作

すべてのLSP機能が正常に動作することを確認してください:

- ✅ 定義/実装/型定義/宣言へのジャンプが機能する
- ✅ JAR内のクラスが自動デコンパイルされる
- ✅ 参照検索で全使用箇所が表示される
- ✅ ホバーでドキュメントが表示される
- ✅ シグネチャヘルプでパラメータ情報が表示される
- ✅ リネームが全ファイルで一括実行される
- ✅ コードアクションが提案される
- ✅ フォーマットが実行される
- ✅ 診断機能が動作する

このテストプロジェクトを使用して、kotlin-extended-lsp.nvimのすべての機能が正しく動作することを確認できます。
