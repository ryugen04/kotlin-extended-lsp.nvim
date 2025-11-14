-- 実装ジャンプ機能
-- textDocument/implementationを使用してインターフェース/抽象クラスの実装へジャンプ

local utils = require('kotlin-extended-lsp.utils')
local M = {}

-- 実装へジャンプ
function M.go_to_implementation()
  local client, err = utils.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- サーバーがtextDocument/implementationをサポートしているか確認
  if not client.supports_method('textDocument/implementation') then
    vim.notify(
      'kotlin-lsp does not support textDocument/implementation',
      vim.log.levels.WARN
    )
    return
  end

  -- 標準LSPメソッドを呼び出し
  -- vim.lsp.buf.implementation()は内部で以下を行う:
  -- 1. textDocument/implementationリクエストを送信
  -- 2. 結果が1件ならジャンプ、複数件ならvim.ui.selectで選択
  vim.lsp.buf.implementation()
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

          -- サポート確認してからキーマップを設定
          if client.supports_method('textDocument/implementation') then
            local keymap_opts = { buffer = bufnr, silent = true }

            -- gi: 実装へジャンプ
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

return M
