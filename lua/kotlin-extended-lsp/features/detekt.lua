-- Detekt リンター統合
-- nvim-lint と統合してDetektによる静的解析を提供
local M = {}

-- デフォルト設定
local default_opts = {
  -- 保存時のみ実行（Detektは重いため）
  lint_on_save_only = true,
  -- Detektの追加引数
  extra_args = {},
}

local opts = {}

--- Detektカスタムリンター定義を登録
---@param lint table nvim-lintのlintモジュール
local function setup_detekt_linter(lint)
  lint.linters.detekt = {
    cmd = 'detekt',
    stdin = false,
    args = function()
      local args = {
        '--input',
        vim.fn.expand('%:p'),
        '--build-upon-default-config',
      }
      -- 追加引数をマージ
      for _, arg in ipairs(opts.extra_args or {}) do
        table.insert(args, arg)
      end
      return args
    end,
    stream = 'both',
    ignore_exitcode = true,
    parser = function(output, bufnr)
      local diagnostics = {}
      local current_file = vim.api.nvim_buf_get_name(bufnr)

      -- Detekt出力形式: /path/to/file.kt:10:5: [RuleId] Description
      for line in output:gmatch('[^\r\n]+') do
        local file, lnum, col, rule_id, message =
          line:match('^(.+%.kt):(%d+):(%d+):%s*%[([^%]]+)%]%s*(.+)$')

        if file and lnum and col and rule_id and message then
          -- ファイル名が一致するかチェック
          local matches = false
          if file == current_file then
            matches = true
          elseif vim.endswith(file, vim.fn.expand('%:t')) then
            matches = true
          elseif vim.endswith(current_file, file) then
            matches = true
          end

          if matches then
            -- severityの判定
            local severity = vim.diagnostic.severity.WARN
            if message:match('^error:') or message:match('^CRITICAL') then
              severity = vim.diagnostic.severity.ERROR
            elseif message:match('^info:') then
              severity = vim.diagnostic.severity.INFO
            end

            table.insert(diagnostics, {
              lnum = tonumber(lnum) - 1,
              col = tonumber(col) - 1,
              end_lnum = tonumber(lnum) - 1,
              end_col = tonumber(col),
              severity = severity,
              source = 'detekt',
              message = message,
              code = rule_id,
            })
          end
        end
      end

      return diagnostics
    end,
  }
end

--- nvim-lintのファイルタイプ設定にKotlinを追加
---@param lint table nvim-lintのlintモジュール
local function setup_linters_by_ft(lint)
  lint.linters_by_ft = lint.linters_by_ft or {}
  lint.linters_by_ft.kotlin = { 'detekt' }
end

--- 自動実行のautocmdを設定
local function setup_autocmd()
  -- Kotlinファイルでの自動lint実行
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
    pattern = "*.kt",
    callback = function()
      local ok, lint = pcall(require, 'lint')
      if not ok then return end

      -- 保存時のみ実行オプションが有効な場合
      if opts.lint_on_save_only then
        -- BufWritePost以外では実行しない
        local event = vim.v.event
        if event and event.trigger ~= 'BufWritePost' then
          return
        end
      end

      lint.try_lint()
    end,
    group = vim.api.nvim_create_augroup('kotlin-detekt-lint', { clear = true }),
  })
end

--- Detekt機能をセットアップ
---@param user_opts? table ユーザー設定
function M.setup(user_opts)
  opts = vim.tbl_deep_extend('force', default_opts, user_opts or {})

  -- nvim-lintが利用可能かチェック
  local ok, lint = pcall(require, 'lint')
  if not ok then
    vim.notify(
      'nvim-lint not found. Detekt integration requires mfussenegger/nvim-lint',
      vim.log.levels.WARN
    )
    return
  end

  -- detektコマンドが利用可能かチェック
  if vim.fn.executable('detekt') ~= 1 then
    vim.notify(
      'detekt not found in PATH. Install detekt CLI for linting support.',
      vim.log.levels.WARN
    )
    return
  end

  -- Detektリンターを登録
  setup_detekt_linter(lint)

  -- ファイルタイプ設定を追加
  setup_linters_by_ft(lint)

  -- 自動実行を設定
  setup_autocmd()
end

--- 手動でlintを実行
function M.lint()
  local ok, lint = pcall(require, 'lint')
  if ok then
    lint.try_lint('detekt')
  end
end

return M
