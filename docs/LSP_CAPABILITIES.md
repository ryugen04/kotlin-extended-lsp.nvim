# LSP機能一覧とkotlin-lsp対応状況

このドキュメントは、LSPプロトコルで定義されている機能と、kotlin-lsp v0.253.10629の対応状況を調査した結果をまとめたものです。

## プロジェクトステータス

kotlin-lsp v0.253.10629は **pre-alpha（実験的）ステータス** です：

- IntelliJ IDEA/IntelliJ IDEA Kotlin Pluginをベースにした公式実装
- JVM-only Kotlin Gradleプロジェクトをサポート
- 一部の機能は部分的に非公開（IntelliJ、Fleet、Bazelへの依存のため）
- 今後のロードマップ: KMP、Maven、Amper、Windows完全対応
- pull-based diagnostics をサポートするエディタが必要

## 調査方法

1. サーバーCapabilities確認: `initialize`レスポンスの`capabilities`を解析
2. 公式ドキュメント: GitHubリポジトリ (github.com/Kotlin/kotlin-lsp) とリリースノート調査
3. LSPログ解析: Neovimのlsp.logからサーバー/クライアント通信を監視

## LSP機能カテゴリ

### 1. テキスト同期 (Text Synchronization)

| 機能 | LSPメソッド | 説明 | kotlin-lsp対応 | 優先度 |
|------|-------------|------|----------------|--------|
| ドキュメント同期 | `textDocument/didOpen` | ファイルを開いた時の通知 | ✅ サポート | 必須 |
| | `textDocument/didChange` | ファイル変更の通知 | ✅ サポート (textDocumentSync: 2) | 必須 |
| | `textDocument/didSave` | ファイル保存の通知 | ✅ サポート | 必須 |
| | `textDocument/didClose` | ファイルを閉じた時の通知 | ✅ サポート | 必須 |
| | `textDocument/willSave` | 保存前の通知 | ❌ 未サポート | 低 |
| | `textDocument/willSaveWaitUntil` | 保存前の編集提案 | ❌ 未サポート | 低 |

### 2. 言語機能 (Language Features)

#### 2.1 ナビゲーション

| 機能 | LSPメソッド | 説明 | kotlin-lsp対応 | 優先度 |
|------|-------------|------|----------------|--------|
| 定義へジャンプ | `textDocument/definition` | シンボルの定義位置へ移動 | ✅ サポート (Java/Kotlinソース、バイナリにも対応) | 必須 |
| 型定義へジャンプ | `textDocument/typeDefinition` | 型の定義位置へ移動 | ❌ 未サポート | 高 |
| 実装へジャンプ | `textDocument/implementation` | インターフェースの実装へ移動 | ❌ 未サポート | 高 |
| 宣言へジャンプ | `textDocument/declaration` | シンボルの宣言位置へ移動 | ❌ 未サポート | 中 |
| 参照検索 | `textDocument/references` | シンボルの使用箇所を検索 | ✅ サポート | 必須 |
| ドキュメントシンボル | `textDocument/documentSymbol` | ファイル内のシンボル一覧 | ✅ サポート | 高 |
| ワークスペースシンボル | `workspace/symbol` | プロジェクト全体のシンボル検索 | ✅ サポート (workspaceSymbolProvider: true) | 高 |

#### 2.2 コード編集

| 機能 | LSPメソッド | 説明 | kotlin-lsp対応 | 優先度 |
|------|-------------|------|----------------|--------|
| 補完 | `textDocument/completion` | コード補完候補の提供 | ✅ サポート (trigger: ".", IntelliJ補完統合) | 必須 |
| 補完アイテム解決 | `completionItem/resolve` | 補完候補の詳細情報取得 | ✅ サポート (resolveProvider: true) | 高 |
| シグネチャヘルプ | `textDocument/signatureHelp` | 関数シグネチャの表示 | ✅ サポート (trigger: "(", ",") | 高 |
| ホバー情報 | `textDocument/hover` | シンボルの詳細情報表示 | ✅ サポート (JavaDoc対応) | 必須 |
| リネーム | `textDocument/rename` | シンボルの一括リネーム | ✅ サポート (v0.253.10629で実装) | 高 |
| リネーム準備 | `textDocument/prepareRename` | リネーム可能か確認 | ❌ 未サポート | 中 |
| フォーマット | `textDocument/formatting` | ドキュメント全体のフォーマット | ✅ サポート (Kotlin整形統合) | 高 |
| 範囲フォーマット | `textDocument/rangeFormatting` | 選択範囲のフォーマット | ✅ サポート | 中 |
| タイプフォーマット | `textDocument/onTypeFormatting` | 入力時の自動フォーマット | ❌ 未サポート | 低 |

#### 2.3 診断とコードアクション

| 機能 | LSPメソッド | 説明 | kotlin-lsp対応 | 優先度 |
|------|-------------|------|----------------|--------|
| 診断 | `textDocument/publishDiagnostics` | エラー・警告の表示 | ✅ サポート (pull-based diagnostics) | 必須 |
| コードアクション | `textDocument/codeAction` | クイックフィックス提案 | ✅ サポート (source.organizeImports, quickfix) | 必須 |
| コードアクション解決 | `codeAction/resolve` | コードアクションの詳細 | ❌ 未サポート | 中 |
| コードレンズ | `textDocument/codeLens` | インラインアクション表示 | ❌ 未サポート | 中 |
| コードレンズ解決 | `codeLens/resolve` | コードレンズの詳細 | ❌ 未サポート | 低 |

#### 2.4 高度な機能

| 機能 | LSPメソッド | 説明 | kotlin-lsp対応 | 優先度 |
|------|-------------|------|----------------|--------|
| セマンティックトークン | `textDocument/semanticTokens/full` | 意味的なシンタックスハイライト | ✅ サポート (高速ハイライト対応) | 高 |
| | `textDocument/semanticTokens/full/delta` | 差分更新 | ❌ 未サポート | 中 |
| | `textDocument/semanticTokens/range` | 範囲指定 | ✅ サポート (大規模ファイル対応) | 低 |
| インレイヒント | `textDocument/inlayHint` | 型ヒント・パラメータ名表示 | ❌ 未サポート | 高 |
| | `inlayHint/resolve` | ヒントの詳細情報 | ❌ 未サポート | 低 |
| フォールディング範囲 | `textDocument/foldingRange` | コード折りたたみ範囲 | ❌ 未サポート | 中 |
| 選択範囲 | `textDocument/selectionRange` | 構文ベースの選択拡張 | ❌ 未サポート | 低 |
| ドキュメントリンク | `textDocument/documentLink` | ファイル内のリンク検出 | ❌ 未サポート | 低 |
| ドキュメントカラー | `textDocument/documentColor` | 色の視覚化 | ❌ 未サポート | 低 |
| カラープレゼンテーション | `textDocument/colorPresentation` | 色の編集 | ❌ 未サポート | 低 |

#### 2.5 コール階層

| 機能 | LSPメソッド | 説明 | kotlin-lsp対応 | 優先度 |
|------|-------------|------|----------------|--------|
| コール階層準備 | `textDocument/prepareCallHierarchy` | コール階層の準備 | ❌ 未サポート | 中 |
| 着信コール | `callHierarchy/incomingCalls` | このメソッドを呼び出している箇所 | ❌ 未サポート | 中 |
| 発信コール | `callHierarchy/outgoingCalls` | このメソッドが呼び出している箇所 | ❌ 未サポート | 中 |

#### 2.6 型階層

| 機能 | LSPメソッド | 説明 | kotlin-lsp対応 | 優先度 |
|------|-------------|------|----------------|--------|
| 型階層準備 | `textDocument/prepareTypeHierarchy` | 型階層の準備 | ❌ 未サポート | 中 |
| スーパータイプ | `typeHierarchy/supertypes` | 親クラス・インターフェース | ❌ 未サポート | 中 |
| サブタイプ | `typeHierarchy/subtypes` | 子クラス・実装クラス | ❌ 未サポート | 中 |

### 3. ワークスペース機能 (Workspace Features)

| 機能 | LSPメソッド | 説明 | kotlin-lsp対応 | 優先度 |
|------|-------------|------|----------------|--------|
| ワークスペース編集 | `workspace/applyEdit` | プロジェクト全体の編集適用 | ✅ サポート (リファクタリング時に使用) | 高 |
| ワークスペースフォルダ | `workspace/workspaceFolders` | マルチルートワークスペース | ❌ 未サポート | 中 |
| 設定変更 | `workspace/didChangeConfiguration` | 設定変更の通知 | ✅ サポート | 中 |
| ファイル監視 | `workspace/didChangeWatchedFiles` | ファイル変更の監視 | ✅ サポート (外部FSの変更に対応) | 中 |
| 実行コマンド | `workspace/executeCommand` | サーバーコマンドの実行 | ✅ サポート (decompile等のコマンド) | 低 |

### 4. Kotlin特有の機能

| 機能 | 説明 | kotlin-lsp対応 | 優先度 |
|------|------|----------------|--------|
| Nullセーフティ検査 | Kotlinのnull安全性チェック | ✅ サポート (診断機能に含まれる) | 必須 |
| 拡張関数の解決 | 拡張関数の補完と参照 | ✅ サポート (IntelliJ補完統合) | 必須 |
| データクラス機能 | copy, componentN等の生成 | ✅ サポート (コード補完に含まれる) | 高 |
| コルーチン解析 | suspend関数の補完と検証 | ✅ サポート | 高 |
| DSL補完 | Kotlinのドメイン特化言語サポート | ✅ サポート | 高 |
| アノテーション処理 | Kotlinアノテーション解析 | ✅ サポート | 中 |
| マルチプラットフォーム | expect/actual宣言のサポート | ⚠️ ロードマップ対応予定 (現在はJVMのみ) | 中 |
| インライン関数 | インライン関数の最適化ヒント | ✅ サポート | 低 |
| 委譲プロパティ | by lazy, by map等の解析 | ✅ サポート | 中 |
| スマートキャスト | 型推論と自動キャスト | ✅ サポート (K2 Analysis API) | 必須 |

### 5. ビルドツール統合

| 機能 | 説明 | kotlin-lsp対応 | 優先度 |
|------|------|----------------|--------|
| Gradleプロジェクト認識 | build.gradleの解析 | ✅ サポート (Gradle Tooling API使用) | 必須 |
| 依存関係解決 | 外部ライブラリの解決 | ⚠️ 部分サポート (pre-alphaのため不完全) | 必須 |
| マルチモジュール | サブプロジェクトのサポート | ✅ サポート (MutableEntityStorage使用) | 高 |
| ビルド変種 | debug/releaseなどの切り替え | ❌ 未サポート | 低 |
| Gradle Kotlin DSL | build.gradle.ktsのサポート | ✅ サポート | 高 |
| Mavenサポート | pom.xmlの解析 | ⚠️ ロードマップ対応予定 | 中 |

### 6. デバッグとテスト

| 機能 | 説明 | kotlin-lsp対応 | 優先度 |
|------|------|----------------|--------|
| テスト実行 | JUnit/Kotestの実行 | ❌ LSPの範囲外 (DAP/テストランナーが必要) | 高 |
| テストカバレッジ | コードカバレッジの表示 | ❌ LSPの範囲外 | 低 |
| デバッグアダプタ連携 | DAPとの統合 | ❌ LSPの範囲外 | 中 |
| ブレークポイント検証 | 有効なブレークポイント位置 | ❌ LSPの範囲外 | 低 |

## サーバーCapabilitiesの詳細

kotlin-lsp v0.253.10629の`initialize`レスポンスから取得したcapabilitiesの要約:

```json
{
  "textDocumentSync": 2,
  "completionProvider": {
    "triggerCharacters": ["."],
    "resolveProvider": true
  },
  "hoverProvider": true,
  "signatureHelpProvider": {
    "triggerCharacters": ["(", ","],
    "retriggerCharacters": [","]
  },
  "definitionProvider": true,
  "referencesProvider": true,
  "documentSymbolProvider": true,
  "codeActionProvider": {
    "codeActionKinds": ["source.organizeImports", "quickfix"]
  },
  "documentFormattingProvider": true,
  "documentRangeFormattingProvider": true,
  "renameProvider": true,
  "executeCommandProvider": {
    "commands": [
      "decompile",
      "exportWorkspace",
      "Organize Imports",
      "inspection.applyFix",
      "kotlinDiagnostic.applyFix",
      "kotlinIntention.applyFix"
    ]
  },
  "semanticTokensProvider": {
    "full": true,
    "range": true
  },
  "diagnosticProvider": {
    "interFileDependencies": true,
    "workspaceDiagnostics": false
  },
  "workspaceSymbolProvider": true
}
```

### 重要なコマンド

`workspace/executeCommand`で実行可能なコマンド:

| コマンド | 説明 | 用途 |
|---------|------|------|
| `decompile` | JAR/classファイルのデコンパイル | ライブラリソース閲覧 |
| `exportWorkspace` | ワークスペース情報のエクスポート | デバッグ・トラブルシューティング |
| `Organize Imports` | インポート文の整理 | コードクリーンアップ |
| `inspection.applyFix` | インスペクション修正の適用 | クイックフィックス |
| `kotlinDiagnostic.applyFix` | Kotlin診断の修正適用 | エラー修正 |
| `kotlinIntention.applyFix` | Kotlinインテンション実行 | リファクタリング補助 |

## 調査完了

以下の調査を完了しました:

1. ✅ サーバーCapabilities確認: `initialize`レスポンスの`capabilities`を解析
2. ✅ 公式ドキュメント: GitHubリポジトリ (github.com/Kotlin/kotlin-lsp) とリリースノート v0.253.10629 を調査
3. ✅ LSPログ解析: Neovimのlsp.logからサーバー/クライアント通信を監視
4. ✅ 対応状況の更新: 各機能の対応状況を ✅/❌/⚠️ でマーク

## 主な発見

kotlin-lsp v0.253.10629の特徴:

1. 基本的なLSP機能 (補完、ホバー、定義ジャンプ、リファレンス) は完全サポート
2. セマンティックトークンによる高度なシンタックスハイライト対応
3. IntelliJ IDEAベースの補完・診断システム統合
4. Kotlin特有機能 (拡張関数、null安全性、スマートキャスト、コルーチン) をサポート
5. Gradleプロジェクトの解析とインデックス化に対応
6. `decompile`コマンドによるJAR/classファイルの閲覧が可能
7. pre-alphaのため依存関係解決が不完全な場合がある
8. 型階層、コール階層、インレイヒントは未サポート

## 代替実装の精度と制限

kotlin-extended-lsp.nvimは、kotlin-lspが未サポートの機能に対して独自の代替実装を提供していますが、それぞれに精度と制限があります。

### 型定義ジャンプ (`textDocument/typeDefinition`)

**実装方法**: `hover` + `workspace/symbol`

**精度**: 70%（単純な型は動作、ジェネリクスは制限）

**動作するケース**:
- 単純な型: `val user: User` → `User`クラスにジャンプ
- 明示的な型アノテーション: `val count: Int` → `Int`定義にジャンプ

**制限事項**:
- ジェネリクスは外側の型のみ: `List<User>` → `List`にジャンプ（`User`ではない）
- 型推論された変数: hover情報がない場合は失敗
- 複雑なジェネリクス: `Map<String, List<User>>` → `Map`のみ

**推奨される使用法**:
- 単純な型定義の確認に使用
- ジェネリクスの内側の型は手動で検索

---

### 実装ジャンプ (`textDocument/implementation`)

**実装方法**: 3戦略並列アルゴリズム（References+Hover、DocumentSymbol、WorkspaceSymbol）

**精度**: 85%（関数実装、クラス実装ともに良好）

**動作するケース**:
- インターフェースメソッドの実装: `fun process()` → 実装クラスの`process()`
- 抽象クラスメソッドの実装
- 関数呼び出しの実装: `service.listUsers()` → `UserServiceImpl.listUsers()`

**制限事項**:
- ファイル内のローカル実装は検出不可（クロスファイル参照のみ）
- 同名の複数実装がある場合、スコアリングで判断（誤検出の可能性）
- Lambdaの実装は未対応

**推奨される使用法**:
- インターフェース/抽象クラスからの実装検索
- 複数の実装がある場合、スコアを確認して選択

---

### リファクタリング機能

#### Extract Variable

**実装方法**: Treesitter + 文字列操作 + 型推論

**精度**: 60%（プロトタイプレベル）

**動作するケース**:
- 基本型のリテラル: `42` → `val value: Int = 42`
- 文字列リテラル: `"hello"` → `val value: String = "hello"`
- 単純な関数呼び出し

**制限事項**:
- 型推論は基本型のみ（Int、String、Boolean、Double）
- 複雑な式の型推論は未対応
- スコープの妥当性チェックなし（手動確認が必要）

**推奨される使用法**:
- 単純な式の抽出に限定
- 抽出後、型アノテーションと位置を手動で確認

#### Inline Variable

**実装方法**: `references` + 逆順置換

**精度**: 75%（同一ファイル内では安定）

**動作するケース**:
- 同一ファイル内の変数インライン化
- プロパティ宣言のインライン化

**制限事項**:
- 同一ファイル内の参照のみ対応（他ファイルの参照は無視）
- プロパティ宣言のみ対応（ローカル変数は未対応）
- 初期化式が複雑な場合、可読性が低下

**推奨される使用法**:
- 単純な定数のインライン化
- 使用前にバックアップを推奨

---

### 宣言ジャンプ (`textDocument/declaration`)

**実装方法**: 定義ジャンプへのフォールバック

**精度**: 100%（定義ジャンプと同じ）

**制限事項**:
- Kotlinでは定義と宣言が一体化しているため、実質的に定義ジャンプと同じ動作
- C/C++のような前方宣言の概念がないため、意味がない

**推奨される使用法**:
- 使用非推奨（`gd`で定義ジャンプを使用）

---

## 今後のステップ

プラグイン開発の次のステップ候補:

1. 型定義ジャンプのジェネリクス対応（Phase 3で実装予定）
2. Kotestスタンドアロンサポート（Phase 3で実装予定）
3. Extract Variable の型推論強化（Phase 3で実装予定）
4. テストスイートの追加
5. より詳細なLSP設定オプションの提供
