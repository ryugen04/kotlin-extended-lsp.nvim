# 実装詳細ドキュメント

kotlin-extended-lsp.nvimのジャンプ機能の技術的な実装詳細

## アーキテクチャ

### ファイル構成

```
lua/kotlin-extended-lsp/
├── init.lua                         # プラグインエントリポイント
├── utils.lua                        # 共通ユーティリティ関数
└── features/
    ├── decompile.lua               # デコンパイル + 定義ジャンプ
    ├── commands.lua                # カスタムコマンド群
    ├── type_definition.lua         # 型定義ジャンプ
    ├── implementation.lua          # 実装ジャンプ
    └── declaration.lua             # 宣言ジャンプ
```

### モジュール設計原則

1. **単一責任の原則**: 各featureモジュールは1つの機能のみを担当
2. **依存関係の最小化**: `utils.lua`のみに依存、feature間の依存は避ける
3. **オプトイン設計**: すべての機能はデフォルトで有効だが、簡単に無効化可能
4. **キーマップの分離**: 各featureモジュールが独自のキーマップを管理

---

## 共通ユーティリティ (utils.lua)

### 主要な関数

#### `get_kotlin_lsp_client(bufnr)`

kotlin-lspクライアントを取得する

```lua
function M.get_kotlin_lsp_client(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = 'kotlin-lsp' })

  if #clients == 0 then
    return nil, 'kotlin-lsp client not found'
  end

  return clients[1], nil
end
```

**用途**: すべてのfeatureモジュールでLSPクライアント取得に使用

**戻り値**:
- 成功時: `client, nil`
- 失敗時: `nil, error_message`

#### `execute_command(command, arguments, callback)`

LSPの`workspace/executeCommand`を実行する

```lua
function M.execute_command(command, arguments, callback)
  local client, err = M.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local params = {
    command = command,
    arguments = arguments or {}
  }

  local success, request_id = client.request('workspace/executeCommand', params, function(err, result)
    if err then
      vim.notify('Command execution failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
      if callback then callback(nil, err) end
      return
    end

    if callback then callback(result, nil) end
  end)

  return success, request_id
end
```

**用途**: デコンパイル、exportWorkspace等のカスタムコマンド実行

#### `create_readonly_buffer(name, content, filetype)`

読み取り専用バッファを作成する

```lua
function M.create_readonly_buffer(name, content, filetype)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_name(buf, name)

  -- 一時的にmodifiableにしてコンテンツを設定
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, '\n'))

  -- 読み取り専用に設定
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  vim.bo[buf].bufhidden = 'hide'

  if filetype then
    vim.bo[buf].filetype = filetype
  end

  return buf
end
```

**用途**: デコンパイル結果の表示

---

## 型定義ジャンプ (type_definition.lua)

### 設計上の課題

kotlin-lspが標準LSPの`textDocument/typeDefinition`をサポートしていないため、以下のワークアラウンドを実装:

1. `textDocument/hover`で型情報を取得
2. Markdownから型名を抽出
3. `workspace/symbol`で型定義を検索
4. SymbolKindでフィルタリング

### 型名抽出ロジック

#### 正規表現パターン

```lua
local TYPE_PATTERNS = {
  -- val name: Type
  var_decl = ':%s*([%u][%w%.]*)',

  -- fun name(): Type
  func_return = '%)%s*:%s*([%u][%w%.]*)',

  -- val name: Type
  property = 'val%s+%w+%s*:%s*([%u][%w%.]*)',

  -- Type<T>
  generic = ':%s*([%u][%w%.]*%b<>?)',
}
```

#### 型名クリーンアップ

```lua
-- Nullable型の ? を除去
type_name = type_name:gsub('%?$', '')

-- ジェネリクスを除去（外側のみ）
-- 例: List<User> → List
type_name = type_name:match('([%u][%w%.]*)') or type_name
```

### Markdownパース処理

```lua
local function extract_type_from_markdown(markdown)
  if type(markdown) == 'table' then
    markdown = table.concat(markdown, '\n')
  end

  local in_code_block = false
  local type_name = nil

  for line in markdown:gmatch('[^\n]+') do
    if line:match('^```') then
      in_code_block = not in_code_block
    elseif in_code_block then
      -- コードブロック内で型名を検索
      for _, pattern in pairs(TYPE_PATTERNS) do
        type_name = line:match(pattern)
        if type_name then
          -- クリーンアップ処理
          type_name = type_name:gsub('%?$', '')
          type_name = type_name:match('([%u][%w%.]*)') or type_name
          break
        end
      end

      if type_name then break end
    end
  end

  return type_name
end
```

### SymbolKindフィルタリング

```lua
local TYPE_SYMBOL_KINDS = {
  [vim.lsp.protocol.SymbolKind.Class] = true,
  [vim.lsp.protocol.SymbolKind.Interface] = true,
  [vim.lsp.protocol.SymbolKind.Enum] = true,
  [vim.lsp.protocol.SymbolKind.Struct] = true,
}

local function filter_type_symbols(symbols)
  local filtered = {}

  for _, symbol in ipairs(symbols) do
    if TYPE_SYMBOL_KINDS[symbol.kind] then
      table.insert(filtered, symbol)
    end
  end

  return filtered
end
```

### 複数結果の処理

```lua
local function handle_symbol_results(symbols, query)
  if #symbols == 0 then
    vim.notify('型定義が見つかりません: ' .. query, vim.log.levels.WARN)
    return
  end

  if #symbols == 1 then
    -- 単一結果: 直接ジャンプ
    vim.lsp.util.jump_to_location(symbols[1].location, 'utf-8')
    vim.notify('型定義へジャンプ: ' .. symbols[1].name, vim.log.levels.INFO)
    return
  end

  -- 複数結果: 選択UI表示
  vim.ui.select(symbols, {
    prompt = '型定義を選択 (' .. #symbols .. '件):',
    format_item = function(symbol)
      local container = symbol.containerName and (' (' .. symbol.containerName .. ')') or ''
      local kind_name = vim.lsp.protocol.SymbolKind[symbol.kind] or 'Unknown'
      return string.format('%s%s [%s]', symbol.name, container, kind_name)
    end,
    kind = 'lsp_type_definition'
  }, function(selected)
    if selected then
      vim.lsp.util.jump_to_location(selected.location, 'utf-8')
      vim.notify('型定義へジャンプ: ' .. selected.name, vim.log.levels.INFO)
    end
  end)
end
```

---

## 実装ジャンプ (implementation.lua)

### シンプルな設計

標準LSPメソッドを使用するため、実装は非常にシンプル:

```lua
function M.go_to_implementation()
  local client, err = utils.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- サポート確認
  if not client.supports_method('textDocument/implementation') then
    vim.notify(
      'kotlin-lsp does not support textDocument/implementation',
      vim.log.levels.WARN
    )
    return
  end

  -- Neovim標準の実装を使用
  vim.lsp.buf.implementation()
end
```

### `vim.lsp.buf.implementation()`の内部動作

Neovimが自動的に以下を処理:
1. `textDocument/implementation`リクエストを送信
2. 結果が1件なら直接ジャンプ
3. 結果が複数件なら`vim.ui.select()`で選択UI表示
4. 結果が0件ならメッセージ表示

---

## 宣言ジャンプ (declaration.lua)

### フォールバック設計

kotlin-lspが`textDocument/declaration`をサポートしていない可能性を考慮:

```lua
function M.go_to_declaration()
  local client, err = utils.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  if not client.supports_method('textDocument/declaration') then
    -- フォールバック: definitionを使用
    vim.notify(
      'kotlin-lsp does not support textDocument/declaration, using definition instead',
      vim.log.levels.INFO
    )
    vim.lsp.buf.definition()
    return
  end

  vim.lsp.buf.declaration()
end
```

### キーマップのデフォルト無効化

Kotlinでは宣言と定義が一体化しているため、実用性が低い。そのため、キーマップはデフォルトで無効:

```lua
function M.setup(opts)
  opts = opts or {}

  -- コマンドは作成
  vim.api.nvim_create_user_command('KotlinGoToDeclaration', function()
    M.go_to_declaration()
  end, { desc = 'Go to declaration (fallback to definition if not supported)' })

  -- キーマップはオプトイン
  if opts.setup_keymaps then
    -- setup_keymaps = true の場合のみ gD を設定
    ...
  end
end
```

---

## デコンパイル統合 (decompile.lua)

### 定義ジャンプの拡張

標準の`gd` (定義ジャンプ) を拡張し、JAR内のファイルを自動的にデコンパイル:

```lua
function M.decompile_under_cursor(opts)
  local params = utils.get_symbol_under_cursor()
  local client, err = utils.get_kotlin_lsp_client()

  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- textDocument/definition を実行
  client.request('textDocument/definition', params, function(err, result)
    vim.schedule(function()
      if err or not result or vim.tbl_isempty(result) then
        -- エラー処理
        return
      end

      -- LocationまたはLocationLinkを解析
      local location = ...
      local uri = location.uri or location.targetUri

      -- JAR内のファイルかチェック
      if is_jar_uri(uri) then
        M.decompile_and_show(uri, opts)
      else
        -- 通常のファイルの場合は標準の定義ジャンプ
        if opts.fallback_definition then
          opts.fallback_definition()
        else
          vim.lsp.buf.definition()
        end
      end
    end)
  end)
end
```

### JAR URI判定

```lua
local function is_jar_uri(uri)
  return uri:match('^jar:file:') ~= nil or uri:match('%.jar!') ~= nil
end
```

### キャッシュ機構

```lua
-- デコンパイル済みバッファのキャッシュ
local decompiled_buffers = {}

-- デコンパイル中のURIを追跡（競合状態を防ぐ）
local decompiling_uris = {}

function M.decompile_and_show(uri, opts)
  -- キャッシュチェック
  if decompiled_buffers[uri] then
    local buf = decompiled_buffers[uri]
    if vim.api.nvim_buf_is_valid(buf) then
      -- 既存バッファを表示
      local win = vim.fn.bufwinid(buf)
      if win ~= -1 then
        vim.api.nvim_set_current_win(win)
      else
        utils.open_buffer_in_split(buf, split_type)
      end
      return
    end
  end

  -- 既にデコンパイル中の場合は待機
  if decompiling_uris[uri] then
    vim.notify('Decompilation already in progress for: ' .. uri, vim.log.levels.WARN)
    return
  end

  decompiling_uris[uri] = true

  -- デコンパイル実行
  utils.execute_command('decompile', { uri }, function(result, err)
    vim.schedule(function()
      decompiling_uris[uri] = nil

      if err or not result or not result.code then
        vim.notify('Decompilation failed', vim.log.levels.ERROR)
        return
      end

      -- バッファ作成
      local buf = utils.create_readonly_buffer(buffer_name, result.code, result.language or 'kotlin')
      decompiled_buffers[uri] = buf
      utils.open_buffer_in_split(buf, split_type)
    end)
  end)
end
```

---

## 非同期処理とスレッド安全性

### `vim.schedule()`の使用

LSPリクエストのコールバックは非同期で実行されるため、UI操作は`vim.schedule()`でラップ:

```lua
client.request('textDocument/hover', params, function(err, result)
  vim.schedule(function()
    -- UI操作はここで安全に実行
    vim.notify('型を検索中: ' .. type_name, vim.log.levels.INFO)

    -- 次のLSPリクエストを送信
    client.request('workspace/symbol', symbol_params, function(err2, symbols)
      vim.schedule(function()
        -- さらにUI操作
        handle_symbol_results(type_symbols, type_name)
      end)
    end)
  end)
end)
```

### 競合状態の防止

デコンパイル機能では、同じURIの重複リクエストを防ぐ:

```lua
-- デコンパイル中のURIを追跡
local decompiling_uris = {}

function M.decompile_and_show(uri, opts)
  if decompiling_uris[uri] then
    vim.notify('Decompilation already in progress', vim.log.levels.WARN)
    return
  end

  decompiling_uris[uri] = true

  utils.execute_command('decompile', { uri }, function(result, err)
    vim.schedule(function()
      decompiling_uris[uri] = nil  -- 完了後にクリア
      -- ...
    end)
  end)

  -- リクエスト送信失敗時もクリア
  if not success then
    decompiling_uris[uri] = nil
  end
end
```

---

## キーマップの管理

### LspAttachイベントの使用

各featureモジュールは`LspAttach`イベントでキーマップを設定:

```lua
function M.setup(opts)
  opts = opts or {}

  -- コマンドは常に作成
  vim.api.nvim_create_user_command('KotlinGoToImplementation', function()
    M.go_to_implementation()
  end, { desc = 'Go to implementation' })

  -- キーマップはオプション
  if opts.setup_keymaps ~= false then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspImplementation', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)

        -- kotlin-lspのみに適用
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf

          -- サポート確認
          if client.supports_method('textDocument/implementation') then
            local keymap_opts = { buffer = bufnr, silent = true }

            vim.keymap.set('n', 'gi', M.go_to_implementation,
              vim.tbl_extend('force', keymap_opts, {
                desc = 'Go to implementation'
              }))
          end
        end
      end
    })
  end
end
```

### autogroupの使用

各featureモジュールは独自のautogroupを作成:

- `KotlinExtendedLspDecompile`
- `KotlinExtendedLspImplementation`
- `KotlinExtendedLspTypeDefinition`
- `KotlinExtendedLspDeclaration`

`{ clear = true }`により、プラグインの再ロード時に古いautocmdがクリアされる。

---

## エラーハンドリング

### 多層防御アプローチ

1. **クライアント存在チェック**
```lua
local client, err = utils.get_kotlin_lsp_client()
if not client then
  vim.notify(err, vim.log.levels.ERROR)
  return
end
```

2. **機能サポート確認**
```lua
if not client.supports_method('textDocument/implementation') then
  vim.notify('kotlin-lsp does not support textDocument/implementation', vim.log.levels.WARN)
  return
end
```

3. **LSPレスポンス検証**
```lua
client.request('textDocument/hover', params, function(err, result)
  if err then
    vim.notify('Hover情報の取得に失敗: ' .. vim.inspect(err), vim.log.levels.ERROR)
    return
  end

  if not result or not result.contents then
    vim.notify('型情報を取得できません', vim.log.levels.WARN)
    return
  end

  -- 処理続行
end)
```

4. **データ検証**
```lua
local type_name = extract_type_from_markdown(markdown)

if not type_name then
  vim.notify('型名を抽出できません', vim.log.levels.WARN)
  return
end
```

---

## テストとデバッグ

### 手動テスト方法

#### 構文チェック
```bash
nvim --headless -c "lua dofile('lua/kotlin-extended-lsp/init.lua')" -c "quit"
```

#### コマンド登録確認
```lua
:lua for name, _ in pairs(vim.api.nvim_get_commands({})) do
  if name:match('^Kotlin') then print(name) end
end
```

#### LSP capabilities確認
```lua
:lua =vim.lsp.get_active_clients()[1].server_capabilities
```

#### 型名抽出テスト
```lua
:lua local md = [[```kotlin\nval user: User = ...\n```]]
:lua local extract = require('kotlin-extended-lsp.features.type_definition').extract_type_from_markdown
:lua print(extract(md))
```

### デバッグログの有効化

Neovim LSPログの確認:
```vim
:lua vim.lsp.set_log_level('debug')
:lua print(vim.lsp.get_log_path())
```

ログファイルを開く:
```bash
tail -f ~/.local/state/nvim/lsp.log
```

---

## パフォーマンス最適化

### 型定義ジャンプの最適化案

1. **hover結果のキャッシュ**
```lua
local hover_cache = {}

function get_hover_info_cached(params, callback)
  local cache_key = params.textDocument.uri .. ':' .. params.position.line .. ':' .. params.position.character

  if hover_cache[cache_key] then
    callback(nil, hover_cache[cache_key])
    return
  end

  client.request('textDocument/hover', params, function(err, result)
    if not err and result then
      hover_cache[cache_key] = result
    end
    callback(err, result)
  end)
end
```

2. **workspace/symbolの結果キャッシュ**
```lua
local symbol_cache = {}

function search_symbol_cached(query, callback)
  if symbol_cache[query] then
    callback(nil, symbol_cache[query])
    return
  end

  client.request('workspace/symbol', { query = query }, function(err, result)
    if not err and result then
      symbol_cache[query] = result
    end
    callback(err, result)
  end)
end
```

### メモリ管理

デコンパイルキャッシュのサイズ制限:
```lua
local MAX_CACHE_SIZE = 50

function add_to_cache(uri, buf)
  if vim.tbl_count(decompiled_buffers) >= MAX_CACHE_SIZE then
    -- 最も古いエントリを削除
    local oldest_uri = next(decompiled_buffers)
    local oldest_buf = decompiled_buffers[oldest_uri]
    if vim.api.nvim_buf_is_valid(oldest_buf) then
      vim.api.nvim_buf_delete(oldest_buf, { force = true })
    end
    decompiled_buffers[oldest_uri] = nil
  end

  decompiled_buffers[uri] = buf
end
```

---

## セキュリティ考慮事項

### URI検証

JAR URIの妥当性確認:
```lua
local function is_valid_jar_uri(uri)
  -- jar:file://で始まり、.jar!を含む
  if not (uri:match('^jar:file:') and uri:match('%.jar!')) then
    return false
  end

  -- パストラバーサル攻撃の防止
  if uri:match('%.%.') then
    return false
  end

  return true
end
```

### 読み取り専用バッファの強制

デコンパイル結果は必ず読み取り専用:
```lua
vim.bo[buf].modifiable = false
vim.bo[buf].readonly = true
vim.bo[buf].buftype = 'nofile'
```

---

最終更新: 2025-11-11
