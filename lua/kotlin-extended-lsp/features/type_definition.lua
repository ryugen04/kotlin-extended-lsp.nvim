-- 型定義へジャンプ機能
-- kotlin-lspがtextDocument/typeDefinitionをサポートしていないため、
-- hover + workspace/symbolで代替実装

local utils = require('kotlin-extended-lsp.utils')
local M = {}

-- 型名抽出の正規表現パターン
local TYPE_PATTERNS = {
  -- val/var 宣言: "val name: Type" or "var name: Type"
  var_decl = ':%s*([%u][%w%.]*)',
  -- 関数戻り値: "fun name(...): Type"
  func_return = '%)%s*:%s*([%u][%w%.]*)',
  -- プロパティ: "val name: Type"
  property = 'val%s+%w+%s*:%s*([%u][%w%.]*)',
  -- ジェネリクス含む: "Type<T>"
  generic = ':%s*([%u][%w%.]*%b<>?)',
}

-- SymbolKindの型定義フィルタ
local TYPE_SYMBOL_KINDS = {
  [vim.lsp.protocol.SymbolKind.Class] = true,
  [vim.lsp.protocol.SymbolKind.Interface] = true,
  [vim.lsp.protocol.SymbolKind.Enum] = true,
  [vim.lsp.protocol.SymbolKind.Struct] = true,
}

-- Markdownから型名を抽出
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
      -- 各パターンで型名を試行
      for _, pattern in pairs(TYPE_PATTERNS) do
        type_name = line:match(pattern)
        if type_name then
          -- クリーンアップ: Nullable型の?を除去
          type_name = type_name:gsub('%?$', '')
          -- ジェネリクスを除去（外側のみ）
          -- 例: List<User> → List
          type_name = type_name:match('([%u][%w%.]*)') or type_name
          break
        end
      end

      if type_name then break end
    end
  end

  return type_name
end

-- workspace/symbolの結果をフィルタ
local function filter_type_symbols(symbols)
  local filtered = {}

  for _, symbol in ipairs(symbols) do
    if TYPE_SYMBOL_KINDS[symbol.kind] then
      table.insert(filtered, symbol)
    end
  end

  return filtered
end

-- 複数結果の処理
local function handle_symbol_results(symbols, query)
  if #symbols == 0 then
    -- 静かに失敗（treesitterフォールバックからの呼び出し時のため）
    return
  end

  if #symbols == 1 then
    -- 単一結果: 直接ジャンプ
    vim.lsp.util.jump_to_location(symbols[1].location, 'utf-8')
    vim.notify('型定義へジャンプ: ' .. symbols[1].name, vim.log.levels.INFO)
    return
  end

  -- 複数結果: ユーザーに選択させる
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

-- メイン関数: 型定義へジャンプ
function M.go_to_type_definition()
  local client, err = utils.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local params = vim.lsp.util.make_position_params()

  -- Step 1: hoverで型情報を取得
  client.request('textDocument/hover', params, function(err, result)
    vim.schedule(function()
      if err then
        vim.notify('Hover情報の取得に失敗: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end

      if not result or not result.contents then
        -- 静かに失敗
        return
      end

      -- Step 2: Markdownから型名を抽出
      local markdown = result.contents.value or result.contents
      local type_name = extract_type_from_markdown(markdown)

      if not type_name then
        -- 静かに失敗
        return
      end

      -- Step 3: workspace/symbolで型定義を検索
      local symbol_params = { query = type_name }
      client.request('workspace/symbol', symbol_params, function(err2, symbols)
        vim.schedule(function()
          if err2 then
            vim.notify('シンボル検索に失敗: ' .. vim.inspect(err2), vim.log.levels.ERROR)
            return
          end

          if not symbols or #symbols == 0 then
            -- 静かに失敗
            return
          end

          -- Step 4: 型関連のシンボルのみフィルタ
          local type_symbols = filter_type_symbols(symbols)

          -- Step 5: 結果処理
          handle_symbol_results(type_symbols, type_name)
        end)
      end)
    end)
  end)
end

-- setup: コマンドとキーマップを設定
function M.setup(opts)
  opts = opts or {}

  -- コマンドを作成
  vim.api.nvim_create_user_command('KotlinGoToTypeDefinition', function()
    M.go_to_type_definition()
  end, {
    desc = 'Go to type definition (experimental)'
  })

  -- キーマップ設定（オプション）
  if opts.setup_keymaps ~= false then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspTypeDefinition', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf
          local keymap_opts = { buffer = bufnr, silent = true }

          -- gy: 型定義へジャンプ
          vim.keymap.set('n', 'gy', M.go_to_type_definition,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Go to type definition'
            }))
        end
      end
    })
  end
end

return M
