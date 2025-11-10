# 実装詳細

このドキュメントは、kotlin-extended-lsp.nvimの内部実装について説明します。

## アーキテクチャ概要

プラグインは以下のコンポーネントで構成されています:

```
kotlin-extended-lsp.nvim
├── lua/kotlin-extended-lsp/init.lua  # メインプラグイン実装
├── scripts/install-lsp.sh            # kotlin-lspインストールスクリプト
└── bin/kotlin-lsp/                   # LSPバイナリ (実行時に配置)
```

## コアコンポーネント

### 1. プラグイン初期化 (init.lua)

#### `get_plugin_root()`

```lua
local function get_plugin_root()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  return vim.fn.fnamemodify(source, ":h:h:h")
end
```

**目的**: プラグインのルートディレクトリを動的に取得

**仕組み**:
1. `debug.getinfo(1, "S")`で現在のスクリプトパスを取得
2. `@`プレフィックスを除去
3. `:h:h:h`で3階層上のディレクトリを取得
   - `lua/kotlin-extended-lsp/init.lua` → ルート

#### `get_lsp_cmd()`

```lua
local function get_lsp_cmd()
  local plugin_root = get_plugin_root()
  local lsp_script = plugin_root .. "/bin/kotlin-lsp/kotlin-lsp.sh"

  if vim.fn.filereadable(lsp_script) == 1 then
    return lsp_script
  end

  if vim.fn.executable('kotlin-lsp') == 1 then
    return 'kotlin-lsp'
  end

  return nil
end
```

**目的**: kotlin-lsp実行ファイルのパスを解決

**検索順序**:
1. プラグイン内の `bin/kotlin-lsp/kotlin-lsp.sh`
2. システムPATHの `kotlin-lsp`
3. 見つからない場合は `nil`

#### `M.setup(opts)`

メイン初期化関数。以下を実行します:

1. **LSPコマンドの検証**
   ```lua
   local lsp_cmd = get_lsp_cmd()
   if not lsp_cmd then
     vim.notify('kotlin-lsp not found. Run: scripts/install-lsp.sh', vim.log.levels.ERROR)
     return
   end
   ```

2. **FileTypeオートコマンドの設定**
   ```lua
   vim.api.nvim_create_autocmd('FileType', {
     pattern = 'kotlin',
     callback = function(ev)
       -- プロジェクトルート検出とLSP起動
     end,
   })
   ```

### 2. プロジェクトルート検出

```lua
local root_patterns = {
  'settings.gradle.kts',
  'settings.gradle',
  'build.gradle.kts',
  'build.gradle',
  'pom.xml',
  '.git'
}

local buf_name = vim.api.nvim_buf_get_name(ev.buf)
local found = vim.fs.find(root_patterns, {
  upward = true,
  path = vim.fs.dirname(buf_name)
})

if #found == 0 then
  vim.notify('Kotlin project root not found', vim.log.levels.WARN)
  return
end

local root_dir = vim.fs.dirname(found[1])
```

**検出ロジック**:
1. 現在のバッファのファイルパスを取得
2. ファイルのディレクトリから上方向に検索
3. パターンに一致する最初のファイルを見つける
4. そのファイルの親ディレクトリをプロジェクトルートとする

**重要な修正点**:
- `path`オプションを指定して、バッファのパスから検索を開始
- 以前は現在のディレクトリから検索していたため、誤ったルートを検出していた

### 3. LSPクライアント起動

```lua
vim.lsp.start({
  name = 'kotlin-lsp',
  cmd = { lsp_cmd, '--stdio' },
  root_dir = root_dir,
  on_attach = function(client, bufnr)
    vim.notify('kotlin-lsp attached to buffer ' .. bufnr, vim.log.levels.INFO)

    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  end,
})
```

**設定項目**:
- `name`: LSPクライアント名（'kotlin-lsp'）
- `cmd`: 起動コマンド（`kotlin-lsp.sh --stdio`）
- `root_dir`: プロジェクトルートディレクトリ
- `on_attach`: クライアント接続時のコールバック（キーマップ設定）

**なぜ `vim.lsp.start()` を使用するのか**:
- `nvim-lspconfig`に依存しない軽量な実装
- プラグインごとに独自のLSP起動ロジックを持つ
- 動的にroot_dirを検出して起動

## インストールスクリプト

### install-lsp.sh の仕組み

```bash
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PLUGIN_ROOT/bin"
KOTLIN_LSP_DIR="$BIN_DIR/kotlin-lsp"
```

**初期化**:
1. スクリプトのディレクトリを取得
2. プラグインルートを計算（scripts/ の親）
3. インストール先ディレクトリを設定

### バージョン取得

```bash
RELEASE_URL="https://api.github.com/repos/Kotlin/kotlin-lsp/releases/latest"
VERSION=$(curl -s "$RELEASE_URL" | grep '"tag_name"' | sed -E 's/.*"tag_name": "kotlin-lsp\/v([0-9.]+)".*/\1/')
```

**GitHubリリースAPIを使用**:
- `/releases/latest`から最新バージョン情報を取得
- `tag_name`からバージョン番号を抽出（例: `kotlin-lsp/v0.253.10629` → `0.253.10629`）

### ダウンロードと展開

```bash
DOWNLOAD_URL="https://download-cdn.jetbrains.com/kotlin-lsp/$VERSION/kotlin-$VERSION.zip"
curl -L -o kotlin-lsp.zip "$DOWNLOAD_URL"

FILE_SIZE=$(stat -f%z kotlin-lsp.zip 2>/dev/null || stat -c%s kotlin-lsp.zip 2>/dev/null)
if [ "$FILE_SIZE" -lt 100 ]; then
    echo "エラー: ダウンロードに失敗しました（ファイルサイズ: $FILE_SIZE バイト）"
    exit 1
fi

unzip -q kotlin-lsp.zip
```

**ダウンロード検証**:
- ファイルサイズが100バイト未満の場合はエラー（404などのHTMLが返された場合を検出）
- macOS (`-f%z`) とLinux (`-c%s`) の両方に対応

### ファイル配置

```bash
if [ ! -f "kotlin-lsp.sh" ] || [ ! -d "lib" ]; then
    echo "エラー: 予期しない解凍構造です"
    exit 1
fi

mkdir -p "$KOTLIN_LSP_DIR"
mv kotlin-lsp.sh kotlin-lsp.cmd lib native "$KOTLIN_LSP_DIR/"
chmod +x "$KOTLIN_LSP_DIR/kotlin-lsp.sh"
```

**展開構造の検証**:
- ZIPはルートに直接ファイルを展開（サブディレクトリなし）
- 必要なファイル: `kotlin-lsp.sh`, `lib/`, `native/`
- 実行権限を付与

### クリーンアップ

```bash
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT
```

**一時ディレクトリ管理**:
- `trap`でスクリプト終了時に自動削除
- エラー時も確実にクリーンアップ

## LSPプロトコルの流れ

### 1. 初期化シーケンス

```
Client (Neovim)                Server (kotlin-lsp)
     |                                |
     |---- initialize request ------->|
     |                                |
     |<--- initialize response -------|
     |  (capabilities情報)           |
     |                                |
     |---- initialized notification ->|
     |                                |
```

**initialize request**:
- `rootUri`: プロジェクトルート（`file:///path/to/project`）
- `capabilities`: クライアントがサポートする機能
- `workspaceFolders`: ワークスペース情報

**initialize response**:
- `capabilities`: サーバーがサポートする機能
  - `completionProvider`
  - `hoverProvider`
  - `definitionProvider`
  - など

### 2. Gradleプロジェクトインポート

kotlin-lsp独自の処理:

```
1. GradleWorkspaceImporter が build.gradle.kts を検出
2. Gradle Tooling API を使用してプロジェクトモデルを取得
3. MutableEntityStorage に構造を構築
   - ModuleEntity (モジュール情報)
   - LibraryEntity (依存ライブラリ)
   - SourceRootEntity (ソースディレクトリ)
4. K2 Analysis API で解析を開始
5. "Project imported and indexed" を通知
```

**ログ例**:
```
[INFO] - Project model updated to version 3 in 26 ms
[INFO] - Project imported and indexed
```

### 3. ドキュメント同期

```
Client                         Server
  |                              |
  |-- textDocument/didOpen ----->|
  |                              |
  |<- textDocument/publishDiagnostics
  |                              |
  |-- textDocument/didChange --->|
  |                              |
  |<- textDocument/publishDiagnostics
  |                              |
```

**診断情報の提供**:
- 構文エラー
- 型エラー
- 未解決参照（unresolved reference）

## パフォーマンス最適化

### LSPクライアントの再利用

同じ `root_dir` で複数のバッファを開いた場合、LSPクライアントは再利用されます:

```lua
vim.lsp.start({
  name = 'kotlin-lsp',
  cmd = { lsp_cmd, '--stdio' },
  root_dir = root_dir,
  -- ...
})
```

Neovimは自動的に:
1. 既存のクライアントで同じ `name` と `root_dir` を探す
2. 見つかれば再利用
3. なければ新規起動

### FileType遅延ロード

```lua
{
  ft = 'kotlin',  -- Kotlinファイルを開くまでロードされない
  config = function()
    require('kotlin-extended-lsp').setup()
  end
}
```

lazy.nvimの`ft`指定により:
- Neovim起動時の負荷を軽減
- Kotlinファイルを開いた時だけプラグインをロード

## デバッグ方法

### LSPログの確認

```vim
:lua print(vim.lsp.get_log_path())
```

ログレベルの変更:
```vim
:lua vim.lsp.set_log_level('DEBUG')
```

### LSPクライアントの確認

```vim
:LspInfo
```

または:
```vim
:lua vim.print(vim.lsp.get_clients())
```

### プロジェクトルート検出のデバッグ

```lua
local buf_name = vim.api.nvim_buf_get_name(0)
local root_patterns = {'build.gradle.kts', 'settings.gradle.kts'}
local found = vim.fs.find(root_patterns, {
  upward = true,
  path = vim.fs.dirname(buf_name)
})
vim.print(found)
vim.print(vim.fs.dirname(found[1]))
```

## 既知の問題と対処法

### 1. Gradle依存関係が解決されない

**原因**: kotlin-lsp v0.253.10629はpre-alphaステータス

**対処法**:
- Gradleビルドを一度実行: `gradle build`
- LSPを再起動: `:LspRestart`
- より安定した`fwcd/kotlin-language-server`を検討

### 2. Java警告メッセージ

```
WARNING: package com.apple.laf not in java.desktop
```

**原因**: IntelliJ Platformがmacの固有APIにアクセスしようとする

**影響**: 警告のみで機能には影響なし

**対処法**: 無視して問題なし（kotlin-lsp側の課題）

### 3. プロジェクトルートが誤検出される

**原因**: 複数のGradleプロジェクトが入れ子になっている

**対処法**:
- より具体的な`root_patterns`を優先順位に追加
- または手動で`root_dir`を指定する設定を追加

## 今後の拡張予定

Step 1（完了）:
- ✅ kotlin-lspの基本統合
- ✅ プロジェクトルート検出
- ✅ 自動インストールスクリプト

Step 2以降:
- JAR/classファイルのデコンパイル機能
- カスタム設定オプション
- より高度なワークスペース管理
