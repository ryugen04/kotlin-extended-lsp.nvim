-- Refactoring features for kotlin-extended-lsp.nvim
-- Provides improved Code Actions UI and custom refactoring operations

local utils = require('kotlin-extended-lsp.utils')
local ts_utils = require('kotlin-extended-lsp.ts_utils')
local M = {}

-- Code Actionsを取得
local function get_code_actions(context)
  local params = vim.lsp.util.make_range_params()
  params.context = context or {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
  }

  local bufnr = vim.api.nvim_get_current_buf()
  local results = {}

  -- 全LSPクライアントからCode Actionsを取得
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  for _, client in ipairs(clients) do
    if client.server_capabilities.codeActionProvider then
      local response = client.request_sync('textDocument/codeAction', params, 5000, bufnr)
      if response and response.result then
        for _, action in ipairs(response.result) do
          table.insert(results, {
            action = action,
            client_id = client.id,
          })
        end
      end
    end
  end

  return results
end

-- Code Actionを実行
local function execute_code_action(action_item)
  local action = action_item.action
  local client = vim.lsp.get_client_by_id(action_item.client_id)

  if not client then
    vim.notify('LSP client not found', vim.log.levels.ERROR)
    return
  end

  -- Command形式の場合
  if action.command then
    local command = action.command
    client.request('workspace/executeCommand', {
      command = command.command,
      arguments = command.arguments,
    }, function(err, result)
      if err then
        vim.notify('Command execution failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end
      vim.notify('Code action executed', vim.log.levels.INFO)
    end)
  -- WorkspaceEdit形式の場合
  elseif action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    vim.notify('Code action applied', vim.log.levels.INFO)
  end
end

-- リファクタリング用Code Actionsピッカー
function M.code_actions_refactor()
  local context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
    only = { 'refactor' }, -- リファクタリング関連のみ
  }

  local actions = get_code_actions(context)

  if #actions == 0 then
    vim.notify('No refactoring actions available', vim.log.levels.WARN)
    return
  end

  -- vim.ui.selectで選択
  vim.ui.select(actions, {
    prompt = 'Select refactoring action:',
    format_item = function(item)
      return item.action.title
    end,
  }, function(selected)
    if selected then
      execute_code_action(selected)
    end
  end)
end

-- 全Code Actionsピッカー（改善版）
function M.code_actions()
  local actions = get_code_actions()

  if #actions == 0 then
    vim.notify('No code actions available', vim.log.levels.WARN)
    return
  end

  -- カテゴリごとにグループ化
  local categorized = {}
  for _, item in ipairs(actions) do
    local kind = item.action.kind or 'other'
    local category = kind:match('^([^%.]+)') or 'other'

    if not categorized[category] then
      categorized[category] = {}
    end
    table.insert(categorized[category], item)
  end

  -- フラット化して表示用に整形
  local formatted_actions = {}
  for category, items in pairs(categorized) do
    for _, item in ipairs(items) do
      table.insert(formatted_actions, {
        display = string.format('[%s] %s', category:upper(), item.action.title),
        action_item = item,
      })
    end
  end

  vim.ui.select(formatted_actions, {
    prompt = 'Select code action:',
    format_item = function(item)
      return item.display
    end,
  }, function(selected)
    if selected then
      execute_code_action(selected.action_item)
    end
  end)
end

-- Extract Variable（独自実装）
function M.extract_variable()
  -- Visual modeの範囲を取得
  local mode = vim.fn.mode()
  if mode ~= 'v' and mode ~= 'V' then
    vim.notify('Extract variable requires visual selection', vim.log.levels.WARN)
    return
  end

  -- 選択範囲を取得
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local bufnr = vim.api.nvim_get_current_buf()

  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3]

  -- 選択されたテキストを取得
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  local selected_text

  if #lines == 1 then
    selected_text = lines[1]:sub(start_col + 1, end_col)
  else
    -- 複数行の場合
    lines[1] = lines[1]:sub(start_col + 1)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    selected_text = table.concat(lines, '\n')
  end

  -- 変数名を入力
  vim.ui.input({
    prompt = 'Variable name: ',
    default = 'value',
  }, function(var_name)
    if not var_name or var_name == '' then
      return
    end

    -- Treesitterで型情報を推測（オプション）
    local type_hint = ''
    if ts_utils.is_treesitter_available() then
      -- TODO: 型推論の実装（将来の拡張）
    end

    -- 変数宣言を生成
    local declaration = string.format('val %s%s = %s', var_name, type_hint, selected_text)

    -- 選択範囲を変数名で置換
    vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { var_name })

    -- 宣言を挿入（選択行の上に）
    local indent = lines[1]:match('^%s*') or ''
    vim.api.nvim_buf_set_lines(bufnr, start_row, start_row, false, { indent .. declaration })

    vim.notify('Variable extracted: ' .. var_name, vim.log.levels.INFO)
  end)
end

-- Inline Variable（独自実装）
function M.inline_variable()
  local bufnr = vim.api.nvim_get_current_buf()

  if not ts_utils.is_treesitter_available() then
    vim.notify('Treesitter is required for inline variable', vim.log.levels.ERROR)
    return
  end

  -- カーソル位置の変数を取得
  local node = ts_utils.get_node_at_cursor(bufnr)
  if not node then
    vim.notify('No symbol found at cursor', vim.log.levels.WARN)
    return
  end

  -- simple_identifierノードを探す
  while node and node:type() ~= 'simple_identifier' do
    node = node:parent()
  end

  if not node then
    vim.notify('No variable found at cursor', vim.log.levels.WARN)
    return
  end

  local var_name = vim.treesitter.get_node_text(node, bufnr)

  -- LSPで参照を取得
  local params = vim.lsp.util.make_position_params()

  vim.lsp.buf_request(bufnr, 'textDocument/references', params, function(err, result)
    if err then
      vim.notify('Failed to get references: ' .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end

    if not result or #result == 0 then
      vim.notify('No references found for: ' .. var_name, vim.log.levels.WARN)
      return
    end

    -- 変数宣言を探す
    local declaration_node = node:parent()
    while declaration_node and declaration_node:type() ~= 'property_declaration' do
      declaration_node = declaration_node:parent()
    end

    if not declaration_node then
      vim.notify('Variable declaration not found', vim.log.levels.WARN)
      return
    end

    -- 初期化式を取得
    local initializer = nil
    for child in declaration_node:iter_children() do
      if child:type() == 'property_delegate' or child:type() == 'call_expression' then
        initializer = vim.treesitter.get_node_text(child, bufnr)
        break
      end
    end

    if not initializer then
      vim.notify('Variable initializer not found', vim.log.levels.WARN)
      return
    end

    -- 確認プロンプト
    local msg = string.format('Inline variable "%s" (%d references)?', var_name, #result)
    vim.ui.select({ 'Yes', 'No' }, {
      prompt = msg,
    }, function(choice)
      if choice ~= 'Yes' then
        return
      end

      -- 全参照を初期化式で置換
      for _, ref in ipairs(result) do
        local ref_uri = ref.uri
        local ref_range = ref.range

        -- 同じファイルの場合のみ処理（簡易実装）
        if ref_uri == vim.uri_from_bufnr(bufnr) then
          local ref_start_row = ref_range.start.line
          local ref_start_col = ref_range.start.character
          local ref_end_row = ref_range['end'].line
          local ref_end_col = ref_range['end'].character

          vim.api.nvim_buf_set_text(
            bufnr,
            ref_start_row,
            ref_start_col,
            ref_end_row,
            ref_end_col,
            { initializer }
          )
        end
      end

      -- 変数宣言を削除
      local decl_start_row, _, decl_end_row, _ = declaration_node:range()
      vim.api.nvim_buf_set_lines(bufnr, decl_start_row, decl_end_row + 1, false, {})

      vim.notify('Variable inlined: ' .. var_name, vim.log.levels.INFO)
    end)
  end)
end

-- setup: コマンドとキーマップを設定
function M.setup(opts)
  opts = opts or {}

  -- コマンドを作成
  vim.api.nvim_create_user_command('KotlinCodeActions', function()
    M.code_actions()
  end, {
    desc = 'Show code actions (improved UI)'
  })

  vim.api.nvim_create_user_command('KotlinRefactor', function()
    M.code_actions_refactor()
  end, {
    desc = 'Show refactoring actions'
  })

  vim.api.nvim_create_user_command('KotlinExtractVariable', function()
    M.extract_variable()
  end, {
    range = true,
    desc = 'Extract selection to variable'
  })

  vim.api.nvim_create_user_command('KotlinInlineVariable', function()
    M.inline_variable()
  end, {
    desc = 'Inline variable at cursor'
  })

  -- キーマップ設定（オプション）
  if opts.setup_keymaps ~= false then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspRefactor', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf
          local keymap_opts = { buffer = bufnr, silent = true }

          -- Code Actions（改善版）
          vim.keymap.set('n', '<leader>ka', M.code_actions,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Kotlin: Code Actions'
            }))

          -- Refactorメニュー
          vim.keymap.set('n', '<leader>kr', M.code_actions_refactor,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Kotlin: Refactor'
            }))

          -- Extract Variable
          vim.keymap.set('v', '<leader>kev', M.extract_variable,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Kotlin: Extract Variable'
            }))

          -- Inline Variable
          vim.keymap.set('n', '<leader>kiv', M.inline_variable,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Kotlin: Inline Variable'
            }))
        end
      end
    })
  end
end

return M
