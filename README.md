# kotlin-extended-lsp.nvim

JetBrains公式kotlin-lspをNeovimで使用するための最小限のプラグイン

## 特徴

- JetBrains公式kotlin-lsp (Standalone版) の統合
- **リファクタリング機能** (NEW!)
  - Code Actions UIの改善（カテゴリ別表示）
  - Extract Variable（選択範囲を変数に抽出）
  - Inline Variable（変数をインライン化）
  - Refactorメニュー
- **Kotlinテスト実行機能**
  - JUnit/Kotestサポート
  - カーソル位置/ファイル/プロジェクト全体のテスト実行
  - テスト結果の可視化（Floating Window）
  - neotest統合対応
- **Treesitterベースの高速ジャンプ機能**
  - ファイル内定義ジャンプの高速化
  - スコープを考慮した正確な定義解決
  - LSPへの自動フォールバック
- **拡張されたジャンプ機能**
  - 型定義ジャンプ (`gy`) - hover + workspace/symbol
  - 実装ジャンプ (`gi`) - definition + workspace/symbol
  - デコンパイル対応の定義ジャンプ
- **外部プラグイン統合**
  - which-key統合（v2, v3対応）
  - Telescope統合
  - neotest統合
  - プログラマブル公開API
- 自動インストールスクリプト付属
- Gradleプロジェクトの自動検出とインデックス化
- カスタムコマンド群（インポート整理、診断修正など）

## インストール

### 1. プラグインマネージャーで追加

**lazy.nvimの場合**:

```lua
{
  'your-username/kotlin-extended-lsp.nvim',
  ft = 'kotlin',
  config = function()
    require('kotlin-extended-lsp').setup()
  end
}
```

**ローカル開発の場合**:

```lua
{
  dir = '~/dev/projects/kotlin-extended-lsp.nvim',
  ft = 'kotlin',
  config = function()
    require('kotlin-extended-lsp').setup()
  end
}
```

### 2. kotlin-lspをインストール

プラグインディレクトリに移動してインストールスクリプトを実行します:

```bash
cd ~/.local/share/nvim/lazy/kotlin-extended-lsp.nvim
./scripts/install-lsp.sh
```

スクリプトは以下を自動的に実行します:
- JetBrains公式リポジトリから最新版をダウンロード
- `bin/kotlin-lsp/`に展開
- 実行権限を設定
- 一時ファイルをクリーンアップ

## 使用方法

Kotlinファイルを開くと自動的にkotlin-lspが起動します。

### 基本機能

プラグインは以下を自動で行います:

1. **プロジェクトルート検出**: `build.gradle.kts`, `settings.gradle.kts`などを基準に検出
2. **LSPサーバー起動**: 検出したルートディレクトリで kotlin-lsp を起動
3. **Gradleプロジェクトインポート**: 依存関係を自動的にインデックス化

### キーマップ

デフォルトで以下のキーマップが設定されます:

| キー | 機能 | 説明 |
|------|------|------|
| `gd` | 定義ジャンプ | Treesitter優先、LSPフォールバック |
| `gy` | 型定義ジャンプ | 変数/プロパティの型定義へジャンプ |
| `gi` | 実装ジャンプ | インターフェース/抽象クラスの実装へ |
| `gr` | 参照表示 | シンボルの使用箇所を表示 |
| `K` | ホバー情報 | カーソル位置の情報を表示 |
| `<leader>rn` | リネーム | シンボルのリネーム |
| `<leader>ca` | コードアクション | 利用可能なコードアクションを表示 |
| `<leader>kd` | デコンパイル | JAR内クラスをデコンパイル |
| `<leader>ko` | インポート整理 | import文を整理 |
| `<leader>kf` | 診断修正 | 診断エラーを修正 |
| `<leader>ktn` | テスト実行（カーソル位置） | カーソル位置のテストを実行 |
| `<leader>ktf` | テスト実行（ファイル） | ファイル全体のテストを実行 |
| `<leader>kta` | テスト実行（全体） | プロジェクト全体のテストを実行 |

### カスタムコマンド

| コマンド | 機能 |
|----------|------|
| `:KotlinGoToTypeDefinition` | 型定義ジャンプ |
| `:KotlinGoToImplementation` | 実装ジャンプ |
| `:KotlinGoToDeclaration` | 宣言ジャンプ |
| `:KotlinDecompile [URI]` | デコンパイル |
| `:KotlinOrganizeImports` | インポート整理 |
| `:KotlinApplyFix` | 診断修正 |
| `:KotlinExportWorkspace` | ワークスペースエクスポート |
| `:KotlinTestNearest` | カーソル位置のテストを実行 |
| `:KotlinTestFile` | ファイル全体のテストを実行 |
| `:KotlinTestAll` | プロジェクト全体のテストを実行 |

### 外部プラグインとの統合

#### which-key との統合

which-keyプラグインを使用している場合、kotlin-extended-lsp.nvimの全機能をwhich-keyから呼び出すことができます。

**which-key v2 の場合**:

```lua
local wk = require('which-key')
local kotlin_api = require('kotlin-extended-lsp.api')

-- LSPジャンプ機能の統合
wk.register(kotlin_api.get_which_key_mappings(), {
  mode = "n",
  prefix = "g",
})

-- Kotlinカスタム機能の統合
wk.register({
  k = kotlin_api.get_which_key_mappings().k,
}, {
  mode = "n",
  prefix = "<leader>",
})
```

**which-key v3 の場合**:

```lua
local wk = require('which-key')
local kotlin_api = require('kotlin-extended-lsp.api')

-- 全機能をまとめて登録
wk.add(kotlin_api.get_which_key_spec())
```

**提供される機能**:
- `gd`: 定義ジャンプ（Treesitter + LSP）
- `gy`: 型定義ジャンプ
- `gi`: 実装ジャンプ
- `gD`: 宣言ジャンプ
- `<leader>kd`: デコンパイル
- `<leader>kc`: デコンパイルキャッシュクリア
- `<leader>ko`: インポート整理
- `<leader>ke`: ワークスペースエクスポート
- `<leader>kf`: 診断修正
- `<leader>ktn`: カーソル位置のテスト実行
- `<leader>ktf`: ファイルのテスト実行
- `<leader>kta`: 全テスト実行

#### neotest との統合

neotestプラグインを使用している場合、kotlin-extended-lsp.nvimのテスト機能をneotestから利用できます。

```lua
require('neotest').setup({
  adapters = {
    require('kotlin-extended-lsp.features.neotest_adapter'),
  },
})
```

**提供される機能**:
- Treesitterベースのテスト検出（JUnit/Kotest対応）
- Gradleテスト実行
- JUnit XMLレポートのパース
- neotestのUI/UX（サマリーウィンドウ、診断、サイン）

**サポートするテストフレームワーク**:
- JUnit (@Test アノテーション)
- Kotest (test("name") { } 構文)

#### Telescope との統合

```lua
local telescope = require('telescope')
local kotlin_api = require('kotlin-extended-lsp.api')

-- カスタムピッカーを作成
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local function kotlin_actions()
  pickers.new({}, {
    prompt_title = 'Kotlin Extended LSP Actions',
    finder = finders.new_table({
      results = kotlin_api.get_telescope_actions(),
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and selection.value.action then
          selection.value.action()
        end
      end)
      return true
    end,
  }):find()
end

-- キーマップ登録
vim.keymap.set('n', '<leader>fk', kotlin_actions, { desc = 'Kotlin Actions' })
```

#### 公開API

プログラムから呼び出す場合は、以下のAPI関数を使用できます:

```lua
local kotlin_api = require('kotlin-extended-lsp.api')

-- ジャンプ機能
kotlin_api.goto_definition()
kotlin_api.goto_type_definition()
kotlin_api.goto_implementation()
kotlin_api.goto_declaration()

-- デコンパイル機能
kotlin_api.decompile()
kotlin_api.decompile_uri('jar:file:///path/to/lib.jar!/com/example/MyClass.kt')
kotlin_api.clear_decompile_cache()

-- カスタムコマンド
kotlin_api.organize_imports()
kotlin_api.export_workspace()
kotlin_api.apply_fix()

-- テスト機能
kotlin_api.test_nearest()
kotlin_api.test_file()
kotlin_api.test_all()
```

## 要件

### 必須

- Neovim 0.10+
- Java 17+ (kotlin-lspの実行に必要)
- Kotlin Gradleプロジェクト

### オプション（推奨）

Treesitterベースのジャンプ機能を利用する場合:

- nvim-treesitter プラグイン
- tree-sitter-kotlin パーサー（**自動インストール対応**）

```lua
-- lazy.nvim
{
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter.configs').setup({
      highlight = { enable = true },
      -- ensure_installedは不要（kotlin-extended-lsp.nvimが自動インストール）
    })
  end
}
```

**自動インストール**:

nvim-treesitterがインストールされていれば、kotlin-extended-lsp.nvimが初回起動時にKotlinパーサーを自動的にインストールします。

手動インストールも可能: `:TSInstall kotlin`

自動インストールを無効化する場合:
```lua
require('kotlin-extended-lsp').setup({
  auto_install_treesitter = false,
})
```

**注意**: Treesitterがインストールされていない場合でも、自動的にLSPベースの実装にフォールバックするため、全ての機能が利用可能です。

## プロジェクト構造

```
kotlin-extended-lsp.nvim/
├── bin/
│   └── kotlin-lsp/              # LSPバイナリ (gitignore対象)
│       ├── kotlin-lsp.sh        # 起動スクリプト
│       ├── lib/                 # JARファイル
│       └── native/              # ネイティブライブラリ
├── lua/
│   └── kotlin-extended-lsp/
│       ├── init.lua             # メインプラグイン
│       ├── api.lua              # 公開API（which-key/Telescope統合用）
│       ├── utils.lua            # 共通ユーティリティ
│       ├── ts_utils.lua         # Treesitterユーティリティ
│       ├── treesitter_setup.lua # Treesitter自動セットアップ
│       └── features/
│           ├── decompile.lua         # JAR/classデコンパイル
│           ├── commands.lua          # カスタムコマンド群
│           ├── type_definition.lua   # 型定義ジャンプ（LSP）
│           ├── implementation.lua    # 実装ジャンプ
│           ├── declaration.lua       # 宣言ジャンプ
│           ├── ts_definition.lua     # Treesitterベースのジャンプ
│           ├── test_runner.lua       # スタンドアロンテストランナー
│           └── neotest_adapter.lua   # neotest統合アダプター
├── docs/
│   ├── JUMP_FEATURES.md             # ジャンプ機能ドキュメント
│   ├── IMPLEMENTATION_DETAILS.md    # 実装詳細
│   └── TREESITTER_INTEGRATION.md    # Treesitter統合ガイド（新規）
├── scripts/
│   └── install-lsp.sh          # インストールスクリプト
├── .gitignore
└── README.md
```

## トラブルシューティング

### LSPが起動しない

1. kotlin-lspが正しくインストールされているか確認:
   ```bash
   ls -la bin/kotlin-lsp/
   ```

2. Javaがインストールされているか確認:
   ```bash
   java -version  # Java 17以上が必要
   ```

3. LSPログを確認:
   ```vim
   :lua print(vim.lsp.get_log_path())
   ```

### プロジェクトルートが検出されない

プロジェクトルートに以下のいずれかのファイルがあることを確認してください:
- `settings.gradle.kts`
- `settings.gradle`
- `build.gradle.kts`
- `build.gradle`
- `pom.xml`

### Treesitterが動作しない

`Treesitter not available, falling back to LSP` の通知が表示される場合:

1. nvim-treesitterがインストールされているか確認:
   ```vim
   :lua print(pcall(require, 'nvim-treesitter'))
   ```

2. Kotlinパーサーがインストールされているか確認:
   ```vim
   :TSInstall kotlin
   ```

3. locals.scmの確認:
   ```bash
   find ~/.local/share/nvim -name "locals.scm" -path "*/queries/kotlin/*"
   ```

**注意**: Treesitterが利用不可の場合でも、全ての機能はLSPフォールバックにより動作します。

## 詳細ドキュメント

- [ジャンプ機能ガイド](docs/JUMP_FEATURES.md) - 全ジャンプ機能の詳細説明
- [実装詳細](docs/IMPLEMENTATION_DETAILS.md) - 技術実装の詳細
- [Treesitter統合ガイド](docs/TREESITTER_INTEGRATION.md) - Treesitterベースのジャンプ機能について

## kotlin-lspサポート状況と代替実装

kotlin-lsp v0.253.10629は現在**pre-alphaステータス**で、一部のLSP標準機能が未実装です。kotlin-extended-lsp.nvimは、未サポート機能に対して独自の代替実装を提供しています。

### ✅ kotlin-lspが完全サポートする機能

| 機能 | LSPメソッド | 説明 |
|------|------------|------|
| 定義ジャンプ | `textDocument/definition` | シンボルの定義へジャンプ |
| 参照検索 | `textDocument/references` | シンボルの使用箇所を検索 |
| ホバー情報 | `textDocument/hover` | 型情報・ドキュメントを表示 |
| リネーム | `textDocument/rename` | シンボルのリネーム |
| 補完 | `textDocument/completion` | コード補完 |
| 診断 | `textDocument/diagnostic` | エラー・警告の表示 |
| インポート整理 | `kotlin/organizeImports` | import文の整理（カスタムコマンド） |
| デコンパイル | `kotlin/decompile` | JAR内クラスのデコンパイル（カスタムコマンド） |

### 🔄 代替実装を提供する機能

kotlin-lspが未サポートの機能について、プラグイン側で独自実装を提供しています：

| 機能 | 標準LSPメソッド | 代替実装方法 | 制限事項 |
|------|---------------|------------|---------|
| **型定義ジャンプ** | `textDocument/typeDefinition` | `hover` + `workspace/symbol` | 推論型は部分対応 |
| **実装ジャンプ** | `textDocument/implementation` | `definition` + `workspace/symbol` | クロスファイル参照のみ |
| **Extract Variable** | `codeAction (refactor.extract)` | Treesitter + 文字列操作 | 単一式のみ対応 |
| **Inline Variable** | `codeAction (refactor.inline)` | `references` + 置換 | 同一ファイル内のみ |

**代替実装の動作**:
- 型定義ジャンプ (`gy`): hover情報から型名を抽出し、workspace/symbolで検索
- 実装ジャンプ (`gi`): 定義のURIを取得後、異なるURIの同名クラスを実装として扱う
- Extract/Inline Variable: Treesitterで構文解析し、LSP referencesで参照を取得

### ❌ 現在未対応の機能

以下の機能はkotlin-lspが未サポートで、プラグイン側でも未実装です：

- **Extract Method/Function** - kotlin-lspの対応待ち
- **Change Signature** - kotlin-lspの対応待ち
- **Code Lens (Run/Debug)** - kotlin-lspの対応待ち

### 一般的な制限事項

- **Gradle依存関係の解決**: 一部の外部ライブラリで補完が効かない場合があります
- **IntelliJ IDEAとの機能差**: kotlin-lspはIntelliJ IDEA/Android Studioと比較して機能が限定的です
- **パフォーマンス**: 大規模プロジェクトでは初回インデックス作成に時間がかかります

### 代替LSPの検討

より安定したLSPが必要な場合は、コミュニティ版の `fwcd/kotlin-language-server` も検討してください。ただし、こちらも一部機能が限定的です。

### Treesitterベースのジャンプ機能

- **ファイル単位の解析**: クロスファイル参照は未対応（LSPフォールバック）
- **型推論の限界**: 明示的な型アノテーションのみ対応
- **ジェネリクス**: 外側の型のみ抽出（`List<User>` → `List`）

詳細は [TREESITTER_INTEGRATION.md](docs/TREESITTER_INTEGRATION.md) を参照してください。

## ライセンス

MIT
