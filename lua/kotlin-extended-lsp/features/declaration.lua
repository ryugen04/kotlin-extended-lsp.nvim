-- 宣言ジャンプ機能
-- textDocument/declarationを使用してシンボルの宣言へジャンプ
-- Kotlinでは定義と宣言が一体化しているため、実用性は低い

local utils = require('kotlin-extended-lsp.utils')
local M = {}

-- 宣言へジャンプ
function M.go_to_declaration()
  local client, err = utils.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- サーバーがtextDocument/declarationをサポートしているか確認
  if not client.supports_method('textDocument/declaration') then
    -- フォールバック: definitionを使用
    vim.notify(
      'kotlin-lsp does not support textDocument/declaration, using definition instead',
      vim.log.levels.INFO
    )
    vim.lsp.buf.definition()
    return
  end

  -- 標準LSPメソッドを呼び出し
  vim.lsp.buf.declaration()
end

-- setup: コマンドとキーマップを設定
function M.setup(opts)
  opts = opts or {}

  -- コマンドを作成
  vim.api.nvim_create_user_command('KotlinGoToDeclaration', function()
    M.go_to_declaration()
  end, {
    desc = 'Go to declaration (fallback to definition if not supported)'
  })

  -- キーマップ設定（オプション）
  -- 注: 宣言ジャンプは標準のgDキーマップと競合する可能性があるため、
  --     デフォルトではキーマップを設定しない
  if opts.setup_keymaps then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspDeclaration', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf
          local keymap_opts = { buffer = bufnr, silent = true }

          -- gD: 宣言へジャンプ
          vim.keymap.set('n', 'gD', M.go_to_declaration,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Go to declaration'
            }))
        end
      end
    })
  end
end

return M
