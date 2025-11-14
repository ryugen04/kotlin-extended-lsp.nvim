# kotlin-extended-lsp.nvim 実装計画

このドキュメントは、Neovimプラグイン開発のベストプラクティスに基づき、不足機能を段階的に実装する全体計画を示します。

## 設計原則

### 1. 疎結合アーキテクチャ
- 各機能は独立したモジュールとして実装
- `lua/kotlin-extended-lsp/features/` 配下に機能ごとのファイルを配置
- コア機能（init.lua）への影響を最小化

### 2. フォールバック戦略
- **コミュニティ版kotlin-lsp (fwcd) は非推奨**のため、フォールバックとして使用しない
- 公式kotlin-lspが未サポートの機能は、プラグイン独自実装またはtreesitter/vim標準機能で代替

### 3. 計算効率とパフォーマンス
- LSPリクエストの最小化（キャッシュ活用）
- 非同期処理（`vim.schedule`, `vim.loop`）の活用
- 大規模ファイル対応（遅延ロード、範囲限定処理）

### 4. Neovimベストプラクティス
- vim.lsp APIの活用
- treesitter連携
- 標準UIコンポーネント（vim.ui.select, vim.diagnostic）の使用
- autocommandの適切な管理

## コミュニティ版kotlin-lsp調査結果

fwcd/kotlin-language-server:
- **ステータス**: 公式kotlin-lspリリースに伴い**非推奨（deprecated）**
- **inlayHints**: 設定は存在するが部分実装の可能性
- **typeDefinition/implementation/callHierarchy**: 明示的なサポート確認できず
- **結論**: フォールバックとして使用せず、独自実装を優先

## 実装優先順位と戦略

### Phase 1: プラグイン側で即座に実装可能な機能（高ROI）

#### 1.1 JAR/classデコンパイル統合
- **優先度**: 最高（実装可能性: 高、実用性: 高）
- **アプローチ**: kotlin-lspの`workspace/executeCommand: decompile`を統合
- **実装方法**:
  - カスタムコマンド `:KotlinDecompile` の追加
  - `gd` (定義ジャンプ) でJAR内シンボルに遭遇時、自動デコンパイルオプション
  - デコンパイル結果を読み取り専用バッファで表示
  - バッファ名: `jar://<path-to-jar>/<class-path>.kt`
- **依存関係**: なし（kotlin-lsp標準機能）
- **テスト**: test-projectで外部ライブラリのクラスにジャンプ

#### 1.2 カスタムコマンド群の公開
- **優先度**: 高（実装可能性: 高、実用性: 中）
- **実装コマンド**:
  - `:KotlinOrganizeImports` - インポート整理
  - `:KotlinApplyFix` - 診断の修正適用
  - `:KotlinExportWorkspace` - ワークスペース情報エクスポート
- **アプローチ**: `workspace/executeCommand` のラッパー
- **実装方法**:
  - `lua/kotlin-extended-lsp/commands.lua` モジュール
  - 各コマンドは独立して実行可能
  - エラーハンドリングとユーザーフィードバック
- **依存関係**: なし（kotlin-lsp標準機能）

#### 1.3 診断の最適化
- **優先度**: 中（実装可能性: 高、実用性: 中）
- **アプローチ**: pull-based diagnostics の設定最適化
- **実装方法**:
  - `vim.diagnostic.config()` のカスタマイズ
  - 診断の表示タイミング・頻度調整
  - 重要度フィルタリング（Error/Warning/Info/Hint）
- **依存関係**: なし

### Phase 2: treesitter/vim標準機能による代替実装（中ROI）

#### 2.1 構文ベースの選択拡張 (Selection Range)
- **優先度**: 中（実装可能性: 中、実用性: 中）
- **アプローチ**: treesitter textobjects で代替
- **実装方法**:
  - nvim-treesitter-textobjects 統合
  - Kotlinの構文ノード（式、文、ブロック、関数）の定義
  - キーマップ: `v` (Visual mode) で段階的に範囲拡大
- **依存関係**: nvim-treesitter, nvim-treesitter-textobjects
- **制限**: LSPベースほどセマンティックに正確ではない

#### 2.2 フォールディング範囲 (Folding Range)
- **優先度**: 低（実装可能性: 高、実用性: 低）
- **アプローチ**: treesitter folding で代替
- **実装方法**:
  - `set foldmethod=expr`
  - `set foldexpr=nvim_treesitter#foldexpr()`
- **依存関係**: nvim-treesitter
- **制限**: 既存のtreesitter機能で十分

### Phase 3: LSP未サポート機能の独自実装（低ROI、高難易度）

#### 3.1 型定義へジャンプ (Type Definition) - 独自実装
- **優先度**: 高（実装可能性: 中、実用性: 高）
- **アプローチ**: LSP hover情報から型を抽出 → workspace/symbol で検索
- **実装方法**:
  1. カーソル位置で `textDocument/hover` を実行
  2. hover結果のMarkdownから型名を抽出（正規表現）
  3. 型名で `workspace/symbol` を検索
  4. 結果が1つ: 直接ジャンプ、複数: `vim.ui.select` で選択
- **キーマップ**: `gy` (go to type definition)
- **制限**:
  - hover情報に型が含まれない場合は失敗
  - ジェネリクス型の解析が複雑
  - 完全な精度は保証できない
- **テスト**: 変数の型、関数の戻り値の型でテスト

#### 3.2 実装へジャンプ (Implementation) - 独自実装
- **優先度**: 高（実装可能性: 中、実用性: 高）
- **アプローチ**: `textDocument/references` の結果をフィルタリング
- **実装方法**:
  1. インターフェース/抽象クラスで `textDocument/references` を実行
  2. 結果を解析:
     - ファイルを読み込み、参照位置の前後コンテキストを確認
     - `class.*:.*InterfaceName` パターンにマッチする行を抽出
  3. 実装クラスのみを `vim.ui.select` で表示
- **キーマップ**: `gI` (go to implementation)
- **制限**:
  - 全ファイルの読み込みが必要（パフォーマンス懸念）
  - 複雑な継承パターンでの精度低下
- **最適化**:
  - 非同期処理
  - ファイル読み込みのキャッシュ
  - treesitterでの構文解析（正規表現より高速）

#### 3.3 インレイヒント (Inlay Hints) - 独自実装
- **優先度**: 最高（実装可能性: 低、実用性: 最高）
- **アプローチ**: LSP hover情報とtreesitterで型情報を推定
- **実装方法**:
  1. treesitterでファイル内の変数宣言・関数定義を抽出
  2. 各位置で `textDocument/hover` を実行（非同期バッチ処理）
  3. 型情報を抽出してextmarkで表示
  4. ファイル変更時に再計算（debounce処理）
- **表示**: `vim.api.nvim_buf_set_extmark` でvirtual textとして表示
- **制限**:
  - LSPリクエストが大量発生（パフォーマンス懸念）
  - hover情報が不完全な場合は表示できない
- **最適化**:
  - 表示範囲を現在のビューポートに限定
  - キャッシュ機構（ファイル変更時のみ再計算）
  - ユーザー設定で有効/無効切り替え

#### 3.4 型階層 (Type Hierarchy) - 独自実装
- **優先度**: 中（実装可能性: 低、実用性: 中）
- **アプローチ**: workspace/symbol + references + テキスト解析
- **実装方法**:
  1. カーソル位置のクラス/インターフェースを特定
  2. `workspace/symbol` でプロジェクト全体のシンボル取得
  3. 各シンボルの定義位置でテキスト解析（継承宣言を探す）
  4. 階層構造を構築してツリー表示
- **制限**:
  - プロジェクト全体のスキャンが必要（非常に重い）
  - 実装難易度が高い
- **代替案**: Phase 3で実装を見送り、kotlin-lsp対応を待つ

#### 3.5 コール階層 (Call Hierarchy) - 独自実装
- **優先度**: 中（実装可能性: 低、実用性: 中）
- **アプローチ**: references + document/symbol + テキスト解析
- **制限**: 型階層と同様に実装難易度が高い
- **代替案**: Phase 3で実装を見送り、kotlin-lsp対応を待つ

### Phase 4: セマンティックトークンのハイライト最適化（低優先度）

- **優先度**: 低（実装可能性: 中、実用性: 低）
- **アプローチ**: kotlin-lspのsemanticTokensをNeovimハイライトグループにマッピング
- **実装方法**:
  - `vim.lsp.semantic_tokens` のカスタマイズ
  - `@lsp.type.function.kotlin` 等のハイライトグループ定義
- **制限**: treesitterで十分な場合が多い

## 実装順序（推奨）

各機能は独立して実装・テスト可能です。以下の順序を推奨します:

### Step 1: JAR/classデコンパイル統合
- **理由**: 実装が簡単で、実用性が高い
- **期待される成果**: 外部ライブラリのソースコード閲覧が可能に
- **実装ファイル**: `lua/kotlin-extended-lsp/features/decompile.lua`

### Step 2: カスタムコマンド群
- **理由**: 実装が簡単で、ユーザビリティ向上
- **期待される成果**: `:KotlinOrganizeImports` 等のコマンドが使用可能に
- **実装ファイル**: `lua/kotlin-extended-lsp/commands.lua`

### Step 3: 型定義へジャンプ
- **理由**: 高優先度、中程度の実装難易度
- **期待される成果**: `gy` で変数の型定義へジャンプ可能に
- **実装ファイル**: `lua/kotlin-extended-lsp/features/type_definition.lua`

### Step 4: 実装へジャンプ
- **理由**: 高優先度、中程度の実装難易度
- **期待される成果**: `gI` でインターフェースの実装クラスへジャンプ可能に
- **実装ファイル**: `lua/kotlin-extended-lsp/features/implementation.lua`

### Step 5: インレイヒント
- **理由**: 最高優先度だが、実装難易度が高い
- **期待される成果**: 変数・パラメータの型情報を自動表示
- **実装ファイル**: `lua/kotlin-extended-lsp/features/inlay_hints.lua`

### Step 6: 診断の最適化
- **理由**: 低優先度、簡単な実装
- **実装ファイル**: `lua/kotlin-extended-lsp/diagnostics.lua`

### Step 7以降: 選択範囲拡張、型階層、コール階層
- **理由**: 低優先度、または高難易度
- **判断**: Step 5完了後、ユーザーフィードバックを元に決定

## プロジェクト構造

```
kotlin-extended-lsp.nvim/
├── lua/
│   └── kotlin-extended-lsp/
│       ├── init.lua                    # メインエントリーポイント
│       ├── commands.lua                # カスタムコマンド群
│       ├── diagnostics.lua             # 診断設定
│       ├── utils.lua                   # 共通ユーティリティ
│       └── features/
│           ├── decompile.lua           # JAR/classデコンパイル
│           ├── type_definition.lua     # 型定義へジャンプ
│           ├── implementation.lua      # 実装へジャンプ
│           └── inlay_hints.lua         # インレイヒント
├── tests/
│   └── kotlin-extended-lsp/
│       ├── decompile_spec.lua
│       ├── type_definition_spec.lua
│       └── implementation_spec.lua
└── docs/
    ├── LSP_CAPABILITIES.md
    ├── MISSING_FEATURES.md
    ├── IMPLEMENTATION.md
    └── IMPLEMENTATION_PLAN.md (this file)
```

## テスト戦略

各機能の実装後、以下のテストを実施:

1. **単体テスト**: test-projectで基本動作確認
2. **統合テスト**: 複雑なKotlinプロジェクトで動作確認
3. **パフォーマンステスト**: 大規模ファイル（1000行以上）での動作確認
4. **エッジケーステスト**: エラーハンドリングの確認

## 次のアクション

Step 1: JAR/classデコンパイル統合の実装を開始します。
