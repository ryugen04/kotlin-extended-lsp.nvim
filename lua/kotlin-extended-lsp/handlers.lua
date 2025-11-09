-- handlers.lua
-- Extended LSP handlers with decompile support

local M = {}

-- デコンパイル対応の定義ジャンプ
local function extended_definition()
  local params = vim.lsp.util.make_position_params()

  vim.lsp.buf_request(0, 'textDocument/definition', params, function(err, result, ctx)
    if err then
      vim.notify('Definition request failed: ' .. tostring(err), vim.log.levels.ERROR)
      return
    end

    if not result or vim.tbl_isempty(result) then
      vim.notify('No definition found', vim.log.levels.WARN)
      return
    end

    -- 単一の結果を取得
    local location = result[1] or result
    local uri = location.uri or location.targetUri

    -- JAR/classファイルの場合はデコンパイル
    if uri:match('%.jar!') or uri:match('%.class$') then
      require('kotlin-extended-lsp.decompile').decompile_and_show(uri, location.range or location.targetRange)
    else
      -- 通常のジャンプ
      vim.lsp.util.jump_to_location(location, 'utf-8')
    end
  end)
end

-- 拡張ハンドラーのセットアップ
function M.setup_extended_handlers(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- gd を拡張版に置き換え
  vim.keymap.set('n', 'gd', extended_definition, opts)

  -- その他の基本的なLSPキーマップ
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
  vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
end

return M
