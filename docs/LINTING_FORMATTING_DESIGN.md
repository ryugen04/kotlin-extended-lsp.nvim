# Linting & Formatting Integration Design

## 要件定義

### 概要
Kotlinの開発において標準的なlinter/formatter（detekt、ktlintなど）を統合し、業務開発のサーバーサイドにおいて一般的なエディタ設定を任意で選択・利用可能にする。

### 機能要件

#### 1. Linting統合
- **detekt**: 包括的なコード分析（コードスメル、バグ検索、スタイルチェック）
  - 100以上のインスペクション
  - カスタム設定ファイルサポート（detekt.yml）
  - 診断情報のLSP diagnosticsへの統合
- **ktlint**: 軽量なコードスタイル分析
  - 公式Kotlinスタイルガイドに準拠
  - Androidスタイルガイドサポート
- **実行タイミング**:
  - 保存時（on_save）
  - 手動実行（コマンド）
  - バッファ変更時（on_type、オプション）

#### 2. Formatting統合
- **ktlint**: デフォルトフォーマッター
  - 公式スタイルガイド準拠
  - 設定可能
- **ktfmt**: Google Java Formatベース
  - Opinionated（非設定的）
  - Google、Kotlinlang、Dropboxスタイル選択可能
- **LSP formatter**: kotlin-lspのビルトインフォーマッター
- **実行タイミング**:
  - 保存時（format_on_save）
  - 手動実行
  - 範囲選択フォーマット
- **優先順位設定**: prefer_formatter オプション

#### 3. エディタ設定
- **.editorconfig サポート**:
  - インデント設定
  - 行末の空白処理
  - 最終行の改行
- **保存時アクション**:
  - インポートの自動整理
  - 末尾の空白削除
  - 最終行の改行挿入
- **その他**:
  - 最大行長の表示
  - インデントガイド（vim設定と連携）

#### 4. カスタマイズ性
- ツールごとの有効/無効切り替え
- カスタム設定ファイルのパス指定
- プロジェクトローカル設定（.git/）
- グローバル設定とローカル設定のマージ

### 非機能要件

1. **パフォーマンス**
   - 非同期実行（vim.loop）
   - デバウンス機能
   - 大規模ファイルのスキップ

2. **エラーハンドリング**
   - ツール未検出時の適切な通知
   - 設定ファイル不正時の警告
   - フォールバック機能

3. **拡張性**
   - プラグイン形式でツール追加可能
   - カスタムツールの登録API

## アーキテクチャ設計

### モジュール構成

```
lua/kotlin-extended-lsp/
├── linter.lua              # Linter統合マネージャー
├── formatter.lua           # Formatter統合マネージャー
├── editor.lua              # エディタ設定
├── tools/
│   ├── detekt.lua         # detekt実装
│   ├── ktlint.lua         # ktlint実装（linter & formatter）
│   └── ktfmt.lua          # ktfmt実装
└── utils/
    └── job.lua            # 非同期ジョブユーティリティ
```

### データフロー

```
User Action (save/command)
    ↓
Handler (linter.lua / formatter.lua)
    ↓
Tool Selection (based on config)
    ↓
Tool Execution (async job)
    ↓
Result Processing
    ↓
LSP Diagnostics / Buffer Update
```

### 設定構造

```lua
{
  linting = {
    enabled = true,
    on_save = true,
    on_type = false,
    debounce_ms = 500,
    tools = {
      detekt = {
        enabled = true,
        config_file = nil, -- auto-detect or specify path
        baseline_file = nil,
        build_upon_default_config = false,
        parallel = true,
      },
      ktlint = {
        enabled = true,
        config_file = nil, -- .editorconfig auto-detected
        android = false, -- use Android style
        experimental = false,
      },
    },
  },
  formatting = {
    enabled = true,
    on_save = false,
    prefer_formatter = 'ktlint', -- 'ktlint', 'ktfmt', 'lsp', 'none'
    tools = {
      ktlint = {
        enabled = true,
        config_file = nil,
        android = false,
      },
      ktfmt = {
        enabled = true,
        style = 'google', -- 'google', 'kotlinlang', 'dropbox'
        max_width = 100,
      },
    },
  },
  editor = {
    editorconfig = true, -- auto-detect and apply .editorconfig
    organize_imports_on_save = true,
    trim_trailing_whitespace = true,
    insert_final_newline = true,
    max_line_length = 120, -- visual guide
  },
}
```

## 実装計画

### Phase 1: 基盤実装
1. `utils/job.lua` - 非同期ジョブユーティリティ
2. 設定スキーマ拡張

### Phase 2: Linting実装
1. `linter.lua` - Linterマネージャー
2. `tools/detekt.lua` - detekt統合
3. `tools/ktlint.lua` - ktlint統合（linter部分）
4. LSP diagnostics統合

### Phase 3: Formatting実装
1. `formatter.lua` - Formatterマネージャー
2. `tools/ktlint.lua` - ktlintフォーマッター
3. `tools/ktfmt.lua` - ktfmtフォーマッター
4. 保存時フォーマットフック

### Phase 4: エディタ設定
1. `editor.lua` - エディタ設定マネージャー
2. .editorconfigパーサー
3. 保存時アクション統合

### Phase 5: 統合とドキュメント
1. `init.lua`への統合
2. コマンド・キーマップ追加
3. README更新
4. ヘルスチェック拡張

## ツール検出方法

1. **プロジェクトローカル**: `./gradlew detekt`、`./gradlew ktlintCheck`
2. **PATH**: `detekt`、`ktlint`、`ktfmt`コマンド
3. **設定指定**: `config.tools.detekt.cmd`など

## 診断情報統合

detekt/ktlintの出力をLSP診断形式に変換:

```lua
{
  lnum = line_number - 1,  -- 0-indexed
  col = column - 1,
  severity = vim.diagnostic.severity.WARN, -- or ERROR
  source = 'detekt' or 'ktlint',
  message = diagnostic_message,
  code = rule_id,
}
```

## コマンド一覧

- `:KotlinLint` - 現在のバッファをリント
- `:KotlinLintProject` - プロジェクト全体をリント
- `:KotlinFormat` - 現在のバッファをフォーマット
- `:KotlinFormatWith [tool]` - 指定ツールでフォーマット
- `:KotlinOrganizeImports` - インポートを整理
- `:KotlinToggleLinting` - Linting有効/無効切り替え
- `:KotlinShowLinterOutput` - Linter出力を表示

## 参考資料

- [detekt](https://github.com/detekt/detekt)
- [ktlint](https://pinterest.github.io/ktlint/)
- [ktfmt](https://github.com/facebook/ktfmt)
- [EditorConfig](https://editorconfig.org/)
