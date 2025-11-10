-- JAR/classファイルのデコンパイル機能

local utils = require('kotlin-extended-lsp.utils')
local M = {}

-- デコンパイル済みバッファのキャッシュ
-- key: URI, value: bufnr
local decompiled_buffers = {}

-- デコンパイル中のURIを追跡（競合状態を防ぐ）
-- key: URI, value: true
local decompiling_uris = {}

-- URIがJAR内のファイルかどうかを判定
local function is_jar_uri(uri)
  return uri:match('^jar:file:') ~= nil or uri:match('%.jar!') ~= nil
end

-- JAR URIからクラス名を抽出
local function extract_class_name(uri)
  -- jar:file:///path/to/lib.jar!/com/example/MyClass.kt
  -- から com/example/MyClass を抽出
  local class_path = uri:match('%.jar!/?(.+)$')
  if not class_path then
    return nil
  end

  -- 先頭のスラッシュを除去（念のため）
  class_path = class_path:gsub('^/', '')

  -- 拡張子を除去（.kt, .class, .java に対応）
  class_path = class_path:gsub('%.kt$', ''):gsub('%.class$', ''):gsub('%.java$', '')

  -- パスをクラス名に変換 (com/example/MyClass → com.example.MyClass)
  local class_name = class_path:gsub('/', '.')

  return class_name
end

-- デコンパイル結果をバッファに表示
function M.decompile_and_show(uri, opts)
  opts = opts or {}
  local split_type = opts.split_type or 'vertical'

  -- 既にデコンパイル済みの場合はキャッシュを使用
  if decompiled_buffers[uri] then
    local buf = decompiled_buffers[uri]
    if vim.api.nvim_buf_is_valid(buf) then
      -- バッファが既に表示されているか確認
      local win = vim.fn.bufwinid(buf)
      if win ~= -1 then
        -- 既に表示されている場合はそのウィンドウにジャンプ
        vim.api.nvim_set_current_win(win)
      else
        -- 表示されていない場合は新しいウィンドウで開く
        utils.open_buffer_in_split(buf, split_type)
      end
      return
    else
      decompiled_buffers[uri] = nil
    end
  end

  -- 既にデコンパイル中の場合は待機
  if decompiling_uris[uri] then
    vim.notify('Decompilation already in progress for: ' .. uri, vim.log.levels.WARN)
    return
  end

  -- デコンパイル中フラグを設定
  decompiling_uris[uri] = true

  -- クラス名を抽出
  local class_name = extract_class_name(uri)
  if not class_name then
    decompiling_uris[uri] = nil  -- エラー時にフラグをクリア
    vim.notify('Failed to extract class name from URI: ' .. uri, vim.log.levels.ERROR)
    return
  end

  vim.notify('Decompiling: ' .. class_name, vim.log.levels.INFO)

  -- decompile コマンドを実行
  local success = utils.execute_command('decompile', { uri }, function(result, err)
    -- UI操作をメインスレッドで実行
    vim.schedule(function()
      -- デコンパイル完了後、フラグをクリア
      decompiling_uris[uri] = nil

      if err then
        vim.notify('Decompilation failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end

      -- kotlin-lspは result.code にデコンパイル結果を返す
      if not result or not result.code then
        vim.notify('Decompilation failed: No code returned', vim.log.levels.ERROR)
        return
      end

      -- バッファ名を生成
      local buffer_name = string.format('jar://%s.kt', class_name:gsub('%.', '/'))

      -- 読み取り専用バッファを作成
      local buf = utils.create_readonly_buffer(buffer_name, result.code, result.language or 'kotlin')

      -- キャッシュに保存
      decompiled_buffers[uri] = buf

      -- 新しいウィンドウで表示
      utils.open_buffer_in_split(buf, split_type)

      vim.notify('Decompilation completed: ' .. class_name, vim.log.levels.INFO)
    end)
  end)

  -- リクエスト送信に失敗した場合、フラグをクリア
  if not success then
    decompiling_uris[uri] = nil
  end
end

-- カーソル位置のシンボルをデコンパイル
function M.decompile_under_cursor(opts)
  local params = utils.get_symbol_under_cursor()
  local client, err = utils.get_kotlin_lsp_client()

  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- textDocument/definition を実行して定義位置を取得
  client.request('textDocument/definition', params, function(err, result)
    -- UI操作をメインスレッドで実行
    vim.schedule(function()
      if err then
        vim.notify('Definition lookup failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end

      if not result or vim.tbl_isempty(result) then
        vim.notify('No definition found', vim.log.levels.WARN)
        return
      end

      -- LSPレスポンスを堅牢に解析
      local location
      if type(result) == 'table' then
        -- 配列形式の場合
        if result[1] ~= nil then
          location = result[1]
        -- LocationまたはLocationLink形式の場合
        elseif result.uri or result.targetUri then
          location = result
        end
      end

      if not location then
        vim.notify('Invalid definition response', vim.log.levels.ERROR)
        return
      end

      local uri = location.uri or location.targetUri
      if not uri then
        vim.notify('Definition location has no URI', vim.log.levels.ERROR)
        return
      end

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

-- 指定URIのデコンパイル（コマンドから直接呼び出し用）
function M.decompile_uri(uri, opts)
  if not is_jar_uri(uri) then
    vim.notify('Not a JAR URI: ' .. uri, vim.log.levels.ERROR)
    return
  end

  M.decompile_and_show(uri, opts)
end

-- キャッシュをクリア
function M.clear_cache()
  for uri, buf in pairs(decompiled_buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  decompiled_buffers = {}
  vim.notify('Decompilation cache cleared', vim.log.levels.INFO)
end

-- setup: キーマップとコマンドを設定
function M.setup(opts)
  opts = opts or {}

  -- コマンドを作成
  vim.api.nvim_create_user_command('KotlinDecompile', function(args)
    if args.args ~= '' then
      -- URI指定の場合
      M.decompile_uri(args.args, opts)
    else
      -- カーソル位置のシンボルをデコンパイル
      M.decompile_under_cursor(opts)
    end
  end, {
    nargs = '?',
    desc = 'Decompile JAR/class file (under cursor or specified URI)'
  })

  vim.api.nvim_create_user_command('KotlinDecompileClearCache', function()
    M.clear_cache()
  end, {
    desc = 'Clear decompilation cache'
  })

  -- デフォルトのキーマップを設定（オプション）
  if opts.setup_keymaps ~= false then
    -- 元のgd動作を保存
    local original_definition = vim.lsp.buf.definition

    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspDecompile', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf
          local opts_keymap = { buffer = bufnr, silent = true }

          -- gd を拡張（JAR内の場合は自動デコンパイル）
          if opts.override_gd ~= false then
            vim.keymap.set('n', 'gd', function()
              -- フォールバック関数を渡す
              local decompile_opts = vim.tbl_extend('force', opts, {
                fallback_definition = original_definition
              })
              M.decompile_under_cursor(decompile_opts)
            end, vim.tbl_extend('force', opts_keymap, {
              desc = 'Go to definition (with decompile support)'
            }))
          end

          -- 明示的なデコンパイルキーマップ
          vim.keymap.set('n', '<leader>kd', function()
            M.decompile_under_cursor(opts)
          end, vim.tbl_extend('force', opts_keymap, {
            desc = 'Kotlin: Decompile under cursor'
          }))
        end
      end
    })
  end
end

return M
