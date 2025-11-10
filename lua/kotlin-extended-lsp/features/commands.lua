-- kotlin-lspのカスタムコマンド群

local utils = require('kotlin-extended-lsp.utils')
local M = {}

-- Organize Imports: インポート文を整理
function M.organize_imports()
  local client, err = utils.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- textDocument/codeActionでOrganize Importsを実行
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(),
    range = {
      start = { line = 0, character = 0 },
      ['end'] = { line = vim.api.nvim_buf_line_count(0), character = 0 }
    },
    context = {
      diagnostics = {},
      only = { 'source.organizeImports' }
    }
  }

  client.request('textDocument/codeAction', params, function(err, result)
    vim.schedule(function()
      if err then
        vim.notify('Organize Imports failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end

      if not result or vim.tbl_isempty(result) then
        vim.notify('No import actions available', vim.log.levels.INFO)
        return
      end

      -- codeActionを実行
      for _, action in ipairs(result) do
        if action.kind == 'source.organizeImports' then
          if action.command then
            -- workspace/executeCommandで実行
            client.request('workspace/executeCommand', action.command, function(cmd_err, cmd_result)
              if cmd_err then
                vim.notify('Command execution failed: ' .. vim.inspect(cmd_err), vim.log.levels.ERROR)
              else
                vim.notify('Imports organized', vim.log.levels.INFO)
              end
            end)
          elseif action.edit then
            -- WorkspaceEditを適用
            vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
            vim.notify('Imports organized', vim.log.levels.INFO)
          end
          return
        end
      end

      vim.notify('No organize imports action found', vim.log.levels.WARN)
    end)
  end)
end

-- Export Workspace: ワークスペース情報をJSONでエクスポート
function M.export_workspace(output_file)
  output_file = output_file or vim.fn.getcwd() .. '/workspace-export.json'

  local success = utils.execute_command('exportWorkspace', {}, function(result, err)
    vim.schedule(function()
      if err then
        vim.notify('Export workspace failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end

      if not result then
        vim.notify('No workspace data returned', vim.log.levels.WARN)
        return
      end

      -- 結果をファイルに書き込み
      local file = io.open(output_file, 'w')
      if not file then
        vim.notify('Failed to open file: ' .. output_file, vim.log.levels.ERROR)
        return
      end

      file:write(vim.fn.json_encode(result))
      file:close()

      vim.notify('Workspace exported to: ' .. output_file, vim.log.levels.INFO)
    end)
  end)

  if not success then
    vim.notify('Failed to send export workspace command', vim.log.levels.ERROR)
  end
end

-- Apply Fix: カーソル位置の診断を修正
function M.apply_fix()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1

  -- 現在行の診断を取得
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line })

  if vim.tbl_isempty(diagnostics) then
    vim.notify('No diagnostics at cursor position', vim.log.levels.INFO)
    return
  end

  -- codeActionリクエストを送信
  local params = vim.lsp.util.make_range_params()
  params.context = {
    diagnostics = diagnostics,
    only = { 'quickfix' }
  }

  local client, err = utils.get_kotlin_lsp_client(bufnr)
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  client.request('textDocument/codeAction', params, function(err, result)
    vim.schedule(function()
      if err then
        vim.notify('Code action failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end

      if not result or vim.tbl_isempty(result) then
        vim.notify('No fixes available', vim.log.levels.INFO)
        return
      end

      -- 複数の修正がある場合は選択UI表示
      if #result == 1 then
        M._apply_code_action(result[1], client)
      else
        vim.ui.select(result, {
          prompt = 'Select fix:',
          format_item = function(action)
            return action.title or 'Unknown action'
          end
        }, function(selected)
          if selected then
            M._apply_code_action(selected, client)
          end
        end)
      end
    end)
  end)
end

-- 内部関数: CodeActionを適用
function M._apply_code_action(action, client)
  if action.command then
    -- workspace/executeCommandで実行
    client.request('workspace/executeCommand', action.command, function(cmd_err, cmd_result)
      vim.schedule(function()
        if cmd_err then
          vim.notify('Fix failed: ' .. vim.inspect(cmd_err), vim.log.levels.ERROR)
        else
          vim.notify('Fix applied: ' .. (action.title or 'Unknown'), vim.log.levels.INFO)
        end
      end)
    end)
  elseif action.edit then
    -- WorkspaceEditを適用
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    vim.notify('Fix applied: ' .. (action.title or 'Unknown'), vim.log.levels.INFO)
  else
    vim.notify('Unknown action type', vim.log.levels.WARN)
  end
end

-- Setup: コマンドを登録
function M.setup(opts)
  opts = opts or {}

  -- :KotlinOrganizeImports コマンド
  vim.api.nvim_create_user_command('KotlinOrganizeImports', function()
    M.organize_imports()
  end, {
    desc = 'Organize Kotlin imports'
  })

  -- :KotlinExportWorkspace コマンド
  vim.api.nvim_create_user_command('KotlinExportWorkspace', function(args)
    M.export_workspace(args.args ~= '' and args.args or nil)
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Export workspace information to JSON'
  })

  -- :KotlinApplyFix コマンド
  vim.api.nvim_create_user_command('KotlinApplyFix', function()
    M.apply_fix()
  end, {
    desc = 'Apply fix for diagnostic at cursor'
  })

  -- オプション: キーマップを設定
  if opts.setup_keymaps ~= false then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspCommands', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf
          local opts_keymap = { buffer = bufnr, silent = true }

          -- <leader>ko: Organize Imports
          vim.keymap.set('n', '<leader>ko', M.organize_imports,
            vim.tbl_extend('force', opts_keymap, {
              desc = 'Kotlin: Organize Imports'
            }))

          -- <leader>kf: Apply Fix
          vim.keymap.set('n', '<leader>kf', M.apply_fix,
            vim.tbl_extend('force', opts_keymap, {
              desc = 'Kotlin: Apply Fix'
            }))
        end
      end
    })
  end
end

return M
