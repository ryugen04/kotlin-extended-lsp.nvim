# NeovimでのサーバーサイドKotlin開発に不足している機能

このドキュメントは、Neovimベテランの視点から、サーバーサイドKotlin開発において不足している機能を優先度順にまとめたものです。

## 1. 高優先度（必須機能）

### 1.1 インレイヒント (Inlay Hints)

**LSPメソッド**: `textDocument/inlayHint`
**kotlin-lsp対応**: ❌ 未サポート
**重要度**: 最重要

#### なぜ必要か

Kotlinは型推論が強力で、変数や戻り値の型が省略されることが多い。サーバーサイド開発では複雑な型（ジェネリクス、関数型、ネストした型）を扱うため、型情報の視覚化は必須。

#### 具体例

```kotlin
// 現状: 型が見えない
val users = repository.findAll()
val result = service.processData(users)

// インレイヒント表示後
val users: List<User> = repository.findAll()
val result: Response<ProcessedData> = service.processData(users)

// 関数パラメータ名の表示
service.create(1L, "John", "john@example.com")
// ↓
service.create(id: 1L, name: "John", email: "john@example.com")
```

#### 現状の代替手段

- `:lua vim.lsp.buf.hover()` (手動で型を確認)
- LSP情報が利用できない場合、型を推測するしかない

---

### 1.2 型定義へジャンプ (Type Definition)

**LSPメソッド**: `textDocument/typeDefinition`
**kotlin-lsp対応**: ❌ 未サポート
**重要度**: 高

#### なぜ必要か

サーバーサイド開発では、変数の宣言位置ではなく、その型の定義を見たいケースが頻繁にある。特に、複雑なDTO、Entityクラスの構造を確認する際に必須。

#### 具体例

```kotlin
// userの型 (User クラス) の定義へジャンプしたい
val user = userService.findById(id)  // カーソルをuserに置く

// 戻り値の型 (Response<User>) の定義へジャンプしたい
fun getUser(): Response<User> = ...  // カーソルを関数名に置く
```

#### `gd` (定義へジャンプ) との違い

- `gd`: 変数`user`の**宣言位置**（この行）へジャンプ
- `型定義へジャンプ`: `User`**クラスの定義**へジャンプ

#### 現状の代替手段

1. `K` (hover) で型を確認
2. 手動で型名を検索 (`:Telescope lsp_workspace_symbols`)
3. `gd`で変数の宣言を見て、そこから型を追う

---

### 1.3 実装へジャンプ (Implementation)

**LSPメソッド**: `textDocument/implementation`
**kotlin-lsp対応**: ❌ 未サポート
**重要度**: 高

#### なぜ必要か

サーバーサイド開発では、インターフェース駆動設計が一般的。インターフェースから実装クラスへの直接ジャンプは、コード理解とデバッグに必須。

#### 具体例

```kotlin
interface UserRepository {
    fun findById(id: Long): User?  // カーソルをfindByIdに置いて実装へジャンプ
}

// → 以下の実装クラスの一覧が表示される
class UserRepositoryImpl : UserRepository { ... }
class MockUserRepository : UserRepository { ... }
class CachedUserRepository : UserRepository { ... }
```

#### `gr` (参照検索) との違い

- `gr`: インターフェースの**使用箇所**を全て表示（呼び出し側、実装クラス、import文など全て含む）
- `実装へジャンプ`: インターフェースの**実装クラス**のみをフィルタして表示

#### 現状の代替手段

1. `gr` (references) で全参照を表示し、手動で実装クラスを探す
2. `:Telescope lsp_workspace_symbols` でクラス名検索
3. ファイル名規則（`*Impl.kt`など）でgrepする

---

### 1.4 型階層 (Type Hierarchy)

**LSPメソッド**: `textDocument/prepareTypeHierarchy`, `typeHierarchy/supertypes`, `typeHierarchy/subtypes`
**kotlin-lsp対応**: ❌ 未サポート
**重要度**: 高

#### なぜ必要か

サーバーサイドでは、インターフェース/抽象クラスの階層構造が複雑。継承関係の把握が開発速度とコードレビューの質に直結する。

#### 具体例

```kotlin
// BaseServiceの継承階層を表示
abstract class BaseService

// スーパータイプ: どの親を継承しているか
class UserService : BaseService(), LoggableService

// サブタイプ: どの子クラスが存在するか
BaseService ← UserService, ProductService, OrderService
```

#### 現状の代替手段

1. `gr` (references) で継承箇所を手動で探す
2. `:Telescope live_grep` で `class.*:.*BaseService` を検索
3. 手動でファイルを開いて確認

---

### 1.5 コール階層 (Call Hierarchy)

**LSPメソッド**: `textDocument/prepareCallHierarchy`, `callHierarchy/incomingCalls`, `callHierarchy/outgoingCalls`
**kotlin-lsp対応**: ❌ 未サポート
**重要度**: 高

#### なぜ必要か

サーバーサイドでは、メソッド呼び出しチェーンが深い。「このAPIエンドポイントがどのサービス層、リポジトリ層を呼んでいるか」の追跡が、パフォーマンス分析とバグ修正に必須。

#### 具体例

```kotlin
// incoming calls: createUserがどこから呼ばれているか
fun createUser(request: CreateUserRequest): User {
    // outgoing calls: createUser内部で何を呼んでいるか
    validate(request)           // ← 1
    val user = repository.save() // ← 2
    eventPublisher.publish()    // ← 3
    return user
}
```

#### 現状の代替手段

1. `gr` (references) で呼び出し元を探す（incoming calls）
2. 関数内を目視で確認（outgoing calls）
3. `:Telescope lsp_document_symbols` で関数一覧を見る

---

## 2. 中優先度（あると便利）

### 2.1 JAR/classファイルのデコンパイル統合

**LSPコマンド**: `decompile`
**kotlin-lsp対応**: ✅ サポート済み
**プラグイン統合**: ❌ 未実装
**重要度**: 中

#### なぜ必要か

サーバーサイド開発では、外部ライブラリ（Spring, Ktor, Exposed, Arrow等）の実装を確認したい場面が頻繁にある。

#### 具体例

```kotlin
import io.ktor.server.application.*

fun Application.module() {
    // Applicationクラスの定義を見たい
    // 現状: JAR内のため見れない
    // 期待: gdでデコンパイルされたソースが開く
}
```

#### 実装方法

kotlin-lspの`workspace/executeCommand` で `decompile` を呼び出し、結果をNeovimバッファで表示する。

#### 現状の代替手段

1. 手動でJARを解凍してデコンパイル
2. IntelliJ IDEAで開く
3. ライブラリのGitHubリポジトリを探す

---

### 2.2 構文ベースの選択拡張 (Selection Range)

**LSPメソッド**: `textDocument/selectionRange`
**kotlin-lsp対応**: ❌ 未サポート
**重要度**: 中

#### なぜ必要か

Neovimベテランは`V` (Visual Line) より細かい選択を好む。Kotlinの式/文/ブロック単位での段階的な選択範囲拡大が効率的。

#### 具体例

```kotlin
val result = users
    .filter { it.isActive }
    .map { it.toDto() }
    .sortedBy { it.name }

// カーソル位置から段階的に選択範囲を拡大
// 1. it.isActive (式)
// 2. { it.isActive } (ラムダ)
// 3. .filter { it.isActive } (メソッドチェーン1つ)
// 4. users.filter...sortedBy (全体)
```

#### 現状の代替手段

- treesitter (`nvim-treesitter-textobjects`) で代替可能
- ただし、LSPベースの方がセマンティックに正確

---

### 2.3 フォールディング範囲 (Folding Range)

**LSPメソッド**: `textDocument/foldingRange`
**kotlin-lsp対応**: ❌ 未サポート
**重要度**: 中

#### なぜ必要か

サーバーサイドのファイルは長くなりがち（500-1000行）。関数/クラス単位でのコード折りたたみが、ファイル全体の構造把握に必要。

#### 現状の代替手段

- treesitter folding (`set foldmethod=expr`, `set foldexpr=nvim_treesitter#foldexpr()`)
- 手動fold (`zf`)

---

## 3. プラグイン側で実装すべき機能

kotlin-lspはサポートしているが、プラグインが提供していない機能。

### 3.1 カスタムコマンドの公開

```vim
:KotlinOrganizeImports    " workspace/executeCommand: "Organize Imports"
:KotlinDecompile          " workspace/executeCommand: "decompile"
:KotlinApplyFix           " workspace/executeCommand: "kotlinDiagnostic.applyFix"
:KotlinExportWorkspace    " workspace/executeCommand: "exportWorkspace"
```

### 3.2 セマンティックトークンのハイライト設定

kotlin-lspはセマンティックトークンをサポートしているが、Neovimのハイライトグループとの連携設定が必要。

```lua
-- セマンティックトークンの色分け
@lsp.type.function.kotlin
@lsp.type.property.kotlin
@lsp.type.parameter.kotlin
@lsp.type.interface.kotlin
```

### 3.3 診断の最適化

- pull-based diagnostics の設定
- 診断の表示頻度・タイミングの調整
- 診断の重要度フィルタリング

---

## まとめ: 不足機能の優先度

### kotlin-lsp未サポート（実装待ち）

1. インレイヒント - 最重要
2. 型定義へジャンプ - 高
3. 実装へジャンプ - 高
4. 型階層 - 高
5. コール階層 - 高
6. 構文ベースの選択拡張 - 中
7. フォールディング範囲 - 中

### プラグイン側で実装可能

1. JAR/classデコンパイル統合 - 中（実装価値が高い）
2. カスタムコマンドの公開 - 中
3. セマンティックトークンのハイライト - 低
4. 診断の最適化 - 低

---

## 次のステップ候補

1. `decompile`コマンドの統合（プラグイン実装可能、実用性が高い）
2. カスタムコマンド（`:KotlinOrganizeImports`等）の追加
3. kotlin-lspへのフィードバック（インレイヒント、型定義、実装へジャンプのリクエスト）
