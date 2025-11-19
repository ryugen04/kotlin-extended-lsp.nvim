-- 実装ジャンプ機能
-- kotlin-lspがtextDocument/implementationをサポートしていないため、
-- workspace/symbolを使った代替実装を提供

local utils = require('kotlin-extended-lsp.utils')
local M = {}

-- クラス名/インターフェース名を抽出
local function extract_symbol_name()
  local params = vim.lsp.util.make_position_params()
  local bufnr = vim.api.nvim_get_current_buf()

  -- カーソル位置の単語を取得
  local word = vim.fn.expand('<cword>')

  return word
end

-- Symbolの種類でフィルタリング
local function filter_implementations(symbols, base_name)
  local filtered = {}

  -- Class, Object, Interfaceのみを対象
  local valid_kinds = {
    [vim.lsp.protocol.SymbolKind.Class] = true,
    [vim.lsp.protocol.SymbolKind.Interface] = true,
    [vim.lsp.protocol.SymbolKind.Object] = true,
  }

  for _, symbol in ipairs(symbols) do
    if valid_kinds[symbol.kind] then
      -- ベース名と一致しない（実装クラス）または関連するシンボルを追加
      if symbol.name ~= base_name or symbol.containerName then
        table.insert(filtered, symbol)
      end
    end
  end

  return filtered
end

-- 実装へジャンプ
function M.go_to_implementation()
  local client, err = utils.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- サーバーが標準メソッドをサポートしている場合は標準を使用
  if client.supports_method('textDocument/implementation') then
    vim.lsp.buf.implementation()
    return
  end

  -- 代替実装: workspace/symbolを使用
  local symbol_name = extract_symbol_name()

  if not symbol_name or symbol_name == '' then
    vim.notify('No symbol found at cursor', vim.log.levels.WARN)
    return
  end

  vim.notify('Searching for implementations of: ' .. symbol_name, vim.log.levels.INFO)

  -- Step 1: カーソル位置のシンボルの定義を取得
  local params = vim.lsp.util.make_position_params()

  client.request('textDocument/definition', params, function(err, result)
    vim.schedule(function()
      if err then
        vim.notify('Failed to get definition: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end

      if not result or vim.tbl_isempty(result) then
        vim.notify('No definition found', vim.log.levels.WARN)
        return
      end

      -- 定義のURIを取得
      local def_uri = type(result) == 'table' and (result[1] or result).uri or result.uri

      -- Step 2: workspace/symbolで実装を検索
      local symbol_params = { query = symbol_name }

      client.request('workspace/symbol', symbol_params, function(err2, symbols)
        vim.schedule(function()
          if err2 then
            vim.notify('Failed to search symbols: ' .. vim.inspect(err2), vim.log.levels.ERROR)
            return
          end

          if not symbols or #symbols == 0 then
            vim.notify('No implementations found', vim.log.levels.WARN)
            return
          end

          -- 実装をフィルタリング（定義自体を除外）
          local implementations = {}
          for _, symbol in ipairs(symbols) do
            -- 定義と異なるURIのシンボルを実装として扱う
            if symbol.location and symbol.location.uri ~= def_uri then
              -- Classまたはオブジェクトのみ
              if symbol.kind == vim.lsp.protocol.SymbolKind.Class or
                 symbol.kind == vim.lsp.protocol.SymbolKind.Object then
                table.insert(implementations, symbol)
              end
            end
          end

          if #implementations == 0 then
            vim.notify('No implementations found for: ' .. symbol_name, vim.log.levels.WARN)
            return
          end

          -- 1つの実装のみの場合は直接ジャンプ
          if #implementations == 1 then
            vim.lsp.util.jump_to_location(implementations[1].location, 'utf-8')
            vim.notify('Jumped to implementation: ' .. implementations[1].name, vim.log.levels.INFO)
            return
          end

          -- 複数の実装がある場合は選択UI
          vim.ui.select(implementations, {
            prompt = 'Select implementation (' .. #implementations .. ' found):',
            format_item = function(symbol)
              local container = symbol.containerName and (' in ' .. symbol.containerName) or ''
              local kind_name = vim.lsp.protocol.SymbolKind[symbol.kind] or 'Unknown'
              return string.format('%s%s [%s]', symbol.name, container, kind_name)
            end,
          }, function(selected)
            if selected then
              vim.lsp.util.jump_to_location(selected.location, 'utf-8')
              vim.notify('Jumped to implementation: ' .. selected.name, vim.log.levels.INFO)
            end
          end)
        end)
      end)
    end)
  end)
end

-- setup: コマンドとキーマップを設定
function M.setup(opts)
  opts = opts or {}

  -- コマンドを作成
  vim.api.nvim_create_user_command('KotlinGoToImplementation', function()
    M.go_to_implementation()
  end, {
    desc = 'Go to implementation'
  })

  -- キーマップ設定（オプション）
  if opts.setup_keymaps ~= false then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspImplementation', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf
          local keymap_opts = { buffer = bufnr, silent = true }

          -- gi: 実装へジャンプ（代替実装を含む）
          vim.keymap.set('n', 'gi', M.go_to_implementation,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Go to implementation'
            }))
        end
      end
    })
  end
end

return M
