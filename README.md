# kotlin-extended-lsp.nvim

> Neovimで[JetBrains公式kotlin-lsp](https://github.com/Kotlin/kotlin-lsp)の機能を拡張し、JARファイルやコンパイル済みクラスへのナビゲーションを可能にするプラグインです。

**注意**: このプラグインはJetBrains公式kotlin-lsp（プレアルファ段階）を使用します。

[![Neovim](https://img.shields.io/badge/Neovim-0.8+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg?style=flat-square&logo=lua)](https://www.lua.org)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

## 概要

kotlin-extended-lsp.nvimは、JetBrains公式kotlin-lspとシームレスに統合し、コンパイル済みのJARファイルやクラスファイル内のコードへジャンプする際に自動的にデコンパイルして表示します。[omnisharp-extended-lsp.nvim](https://github.com/Hoffs/omnisharp-extended-lsp.nvim)からインスピレーションを得て開発されました。

## 主な機能

- JARファイル、クラスファイルへの定義ジャンプ時の自動デコンパイル
- 標準的なLSP操作（定義、実装、型定義、宣言へのジャンプ）の拡張
- デコンパイル結果のキャッシュによる高速化
- カスタマイズ可能なキーマップとUIオプション
- パフォーマンスチューニングオプション
- 詳細なロギングとヘルスチェック機能

## 動作デモ

<!-- デモGIFをここに配置 -->
```
[デモGIFのプレースホルダー]
JARファイル内のKotlinコードへジャンプし、
自動的にデコンパイルされた内容を表示
```

## 必要要件

- Neovim 0.8以上
- [JetBrains公式kotlin-lsp](https://github.com/Kotlin/kotlin-lsp)がインストールされ、設定されていること
  - インストール方法: `brew install JetBrains/utils/kotlin-lsp`
  - 現在プレアルファ段階です
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)（推奨）

## インストール

### lazy.nvim

```lua
{
  'yourusername/kotlin-extended-lsp.nvim',
  dependencies = { 'neovim/nvim-lspconfig' },
  ft = 'kotlin',
  config = function()
    require('kotlin-extended-lsp').setup({
      -- 設定オプション
    })
  end,
}
```

### packer.nvim

```lua
use {
  'yourusername/kotlin-extended-lsp.nvim',
  requires = { 'neovim/nvim-lspconfig' },
  ft = 'kotlin',
  config = function()
    require('kotlin-extended-lsp').setup({
      -- 設定オプション
    })
  end,
}
```

### vim-plug

```vim
Plug 'neovim/nvim-lspconfig'
Plug 'yourusername/kotlin-extended-lsp.nvim'

" init.luaまたはLuaスクリプト内で
lua << EOF
require('kotlin-extended-lsp').setup({
  -- 設定オプション
})
EOF
```

## クイックスタート

最小限の設定例です。

```lua
require('kotlin-extended-lsp').setup({
  enabled = true,
  auto_setup_keymaps = true,
})

-- kotlin-lspの設定
require('lspconfig').kotlin_lsp.setup({
  -- 標準的なLSP設定
})
```

この設定により、Kotlinファイルを開いたときに自動的にプラグインが有効化され、デフォルトのキーマップが設定されます。

## 詳細設定

すべてのデフォルト値を含む完全な設定例です。

```lua
require('kotlin-extended-lsp').setup({
  -- プラグインの有効化
  enabled = true,

  -- キーマップの自動設定
  auto_setup_keymaps = true,
  keymaps = {
    -- ナビゲーション（ジャンプ機能）
    definition = 'gd',          -- 定義へジャンプ
    implementation = 'gi',      -- 実装へジャンプ
    type_definition = 'gy',     -- 型定義へジャンプ
    declaration = 'gD',         -- 宣言へジャンプ
    references = 'gr',          -- 参照検索

    -- ドキュメント表示
    hover = 'K',                -- ホバードキュメント
    signature_help = '<C-k>',   -- シグネチャヘルプ

    -- 編集機能
    rename = '<leader>rn',      -- シンボルリネーム
    code_action = '<leader>ca', -- コードアクション
    format = '<leader>f',       -- フォーマット

    -- 診断機能
    goto_prev = '[d',           -- 前の診断へ移動
    goto_next = ']d',           -- 次の診断へ移動
    open_float = '<leader>e',   -- 診断フロート表示
    setloclist = '<leader>q',   -- 診断をロケーションリストへ
  },

  -- 動作設定
  use_global_handlers = false,      -- グローバルハンドラーを使用
  silent_fallbacks = false,         -- フォールバック時に通知しない
  decompile_on_jar = true,          -- JAR内へジャンプ時に自動デコンパイル
  show_capabilities_on_attach = false,  -- アタッチ時にサーバー機能を表示

  -- デコンパイル設定
  decompile = {
    show_line_numbers = true,       -- 行番号を表示
    syntax_highlight = true,        -- シンタックスハイライトを有効化
    auto_close_on_leave = false,    -- バッファを離れたときに自動で閉じる
    prefer_source = true,           -- ソースが利用可能な場合は優先
  },

  -- パフォーマンス設定
  performance = {
    debounce_ms = 100,              -- デバウンス時間（ミリ秒）
    max_file_size = 1024 * 1024,    -- 最大ファイルサイズ（1MB）
    cache_enabled = true,           -- キャッシュを有効化
    cache_ttl = 3600,               -- キャッシュの有効期限（秒）
  },

  -- LSP設定
  lsp = {
    timeout_ms = 5000,              -- タイムアウト時間
    retry_count = 3,                -- リトライ回数
    retry_delay_ms = 500,           -- リトライ間隔
  },

  -- ロギング設定
  log = {
    level = 'info',                 -- trace, debug, info, warn, error, off
    use_console = true,             -- コンソールに出力
    use_file = false,               -- ファイルに出力
    file_path = vim.fn.stdpath('cache') .. '/kotlin-extended-lsp.log',
  },

  -- UI設定
  ui = {
    float = {
      border = 'rounded',           -- フロートウィンドウのボーダースタイル
      max_width = 100,              -- 最大幅
      max_height = 30,              -- 最大高さ
    },
    signs = {
      decompiled = '󰘧',             -- デコンパイル済みサイン
      loading = '󰔟',                -- ロード中サイン
      error = '',                  -- エラーサイン
    },
  },
})
```

## コマンド

プラグインは以下のユーザーコマンドを提供します。

### `:KotlinLspCapabilities`

kotlin-lspサーバーの機能情報を表示します。

```vim
:KotlinLspCapabilities
```

### `:KotlinDecompile [uri]`

指定したURIのJAR/クラスファイルをデコンパイルします。引数を省略した場合、現在のバッファのファイルをデコンパイルします。

```vim
:KotlinDecompile
:KotlinDecompile jar:file:///path/to/library.jar!/com/example/MyClass.class
```

### `:KotlinClearCache`

デコンパイルキャッシュをクリアします。

```vim
:KotlinClearCache
```

### `:KotlinToggleLog [level]`

ログレベルを変更します。引数を省略した場合、現在のログレベルを表示します。

```vim
:KotlinToggleLog debug
:KotlinToggleLog info
:KotlinToggleLog
```

利用可能なレベル: `trace`, `debug`, `info`, `warn`, `error`, `off`

### `:KotlinShowConfig`

現在の設定を表示します。

```vim
:KotlinShowConfig
```

### `:KotlinExtendedLspHealth`

プラグインのヘルスチェックを実行します。

```vim
:KotlinExtendedLspHealth
```

## キーマップ

デフォルトのキーマップは以下の通りです（`auto_setup_keymaps = true`の場合）。

### ナビゲーション（ジャンプ機能）

| キー | 機能 | 説明 |
|------|------|------|
| `gd` | 定義へジャンプ | JARファイル内の定義も自動デコンパイル |
| `gi` | 実装へジャンプ | 実装が見つからない場合は定義へフォールバック |
| `gy` | 型定義へジャンプ | 型の定義位置へジャンプ |
| `gD` | 宣言へジャンプ | 宣言位置へジャンプ |
| `gr` | 参照検索 | シンボルの参照箇所を検索 |

### ドキュメント表示

| キー | 機能 | 説明 |
|------|------|------|
| `K` | ホバードキュメント | カーソル位置のシンボルのドキュメントを表示 |
| `<C-k>` | シグネチャヘルプ | 関数のシグネチャ情報を表示（挿入モードでも利用可） |

### 編集機能

| キー | 機能 | 説明 |
|------|------|------|
| `<leader>rn` | シンボルリネーム | カーソル位置のシンボルをリネーム |
| `<leader>ca` | コードアクション | 利用可能なコードアクションを表示（ビジュアルモードでも利用可） |
| `<leader>f` | フォーマット | ドキュメント全体または選択範囲をフォーマット |

### 診断機能

| キー | 機能 | 説明 |
|------|------|------|
| `[d` | 前の診断へ移動 | 前のエラー・警告へジャンプ |
| `]d` | 次の診断へ移動 | 次のエラー・警告へジャンプ |
| `<leader>e` | 診断フロート表示 | カーソル位置の診断をフロートウィンドウで表示 |
| `<leader>q` | 診断をロケーションリストへ | すべての診断をロケーションリストに設定 |

### キーマップのカスタマイズ

キーマップは設定で自由にカスタマイズできます。空文字列に設定すると、そのキーマップは無効化されます。

```lua
require('kotlin-extended-lsp').setup({
  keymaps = {
    -- ナビゲーション
    definition = '<leader>gd',
    implementation = '<leader>gi',
    type_definition = '',  -- 無効化
    declaration = '',      -- 無効化
    references = 'gr',

    -- ドキュメント
    hover = 'K',
    signature_help = '<C-s>',  -- Ctrl-sに変更

    -- 編集
    rename = '<F2>',           -- F2に変更
    code_action = '<leader>ca',
    format = '<leader>lf',     -- <leader>lfに変更

    -- 診断
    goto_prev = '[e',          -- [eに変更
    goto_next = ']e',          -- ]eに変更
    open_float = 'gl',         -- glに変更
    setloclist = '',           -- 無効化
  },
})
```

## ヘルスチェック

プラグインの状態を確認するには、以下のコマンドを実行します。

```vim
:KotlinExtendedLspHealth
```

または、Neovimの標準ヘルスチェック機能を使用できます。

```vim
:checkhealth kotlin-extended-lsp
```

ヘルスチェックでは、以下の項目が確認されます。

- プラグインの初期化状態
- kotlin-lspサーバーの接続状態
- サーバーがサポートする機能
- デコンパイル機能の利用可否
- キャッシュの状態

## トラブルシューティング

### JARファイル内へジャンプできない

1. JetBrains公式kotlin-lspが正しくインストールされているか確認してください
   - `brew install JetBrains/utils/kotlin-lsp`
2. ヘルスチェックを実行して、`kotlin/jarClassContents`コマンドが利用可能か確認してください
3. ログレベルを`debug`に設定して、詳細なログを確認してください

```lua
:KotlinToggleLog debug
```

### デコンパイル結果が表示されない

1. ファイルサイズが`performance.max_file_size`を超えていないか確認してください
2. キャッシュをクリアしてみてください: `:KotlinClearCache`
3. タイムアウト時間を延長してみてください

```lua
require('kotlin-extended-lsp').setup({
  lsp = {
    timeout_ms = 10000,  -- 10秒に延長
  },
})
```

### パフォーマンスが遅い

1. キャッシュが有効になっているか確認してください
2. デバウンス時間を調整してください
3. 最大ファイルサイズを制限してください

```lua
require('kotlin-extended-lsp').setup({
  performance = {
    cache_enabled = true,
    debounce_ms = 200,
    max_file_size = 512 * 1024,  -- 512KBに制限
  },
})
```

### ログファイルを確認したい

ログファイル出力を有効にして、詳細を確認できます。

```lua
require('kotlin-extended-lsp').setup({
  log = {
    level = 'debug',
    use_file = true,
    file_path = vim.fn.stdpath('cache') .. '/kotlin-extended-lsp.log',
  },
})
```

ログファイルの場所:

```bash
# Unix/Linux/macOS
~/.cache/nvim/kotlin-extended-lsp.log

# Windows
~/AppData/Local/nvim-data/kotlin-extended-lsp.log
```

## 貢献

貢献を歓迎します。バグ報告、機能提案、プルリクエストはすべて歓迎されます。

詳細は[CONTRIBUTING.md](CONTRIBUTING.md)をご覧ください。

## ライセンス

MIT License - 詳細は[LICENSE](LICENSE)ファイルをご覧ください。

## 謝辞

このプロジェクトは以下のプロジェクトに感謝します。

- [JetBrains公式kotlin-lsp](https://github.com/Kotlin/kotlin-lsp) - 公式Kotlin言語サーバー実装（プレアルファ段階）
- [omnisharp-extended-lsp.nvim](https://github.com/Hoffs/omnisharp-extended-lsp.nvim) - このプラグインのインスピレーション源
- Neovimコミュニティ - 素晴らしいエディタとエコシステム

## リンク

- [Issue Tracker](https://github.com/yourusername/kotlin-extended-lsp.nvim/issues)
- [Pull Requests](https://github.com/yourusername/kotlin-extended-lsp.nvim/pulls)
- [Changelog](https://github.com/yourusername/kotlin-extended-lsp.nvim/releases)
