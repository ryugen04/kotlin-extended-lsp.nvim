-- kotlin-lspのカスタムコマンド群

local utils = require('kotlin-extended-lsp.utils')
local M = {}

local function get_plugin_root()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  return vim.fn.fnamemodify(source, ":h:h:h")
end

local function run_system(cmd, opts, callback)
  opts = opts or {}

  if vim.system then
    vim.system(cmd, opts, function(result)
      callback(result.code, result.stdout, result.stderr)
    end)
    return
  end

  local stdout, stderr = {}, {}
  local handle = vim.fn.jobstart(cmd, {
    cwd = opts.cwd,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr, data)
      end
    end,
    on_exit = function(_, code)
      callback(code, table.concat(stdout, "\n"), table.concat(stderr, "\n"))
    end,
  })

  if handle <= 0 then
    callback(1, "", "jobstart failed")
  end
end

local function normalize_version(version)
  if not version then
    return nil
  end

  version = version:gsub("^kotlin%-lsp/", "")
  version = version:gsub("^v", "")
  return version
end

local function compare_versions(a, b)
  if not a or not b then
    return nil
  end

  local function split_version(v)
    local parts = {}
    for part in v:gmatch("%d+") do
      table.insert(parts, tonumber(part))
    end
    return parts
  end

  local a_parts = split_version(a)
  local b_parts = split_version(b)
  local max_len = math.max(#a_parts, #b_parts)

  for i = 1, max_len do
    local a_val = a_parts[i] or 0
    local b_val = b_parts[i] or 0
    if a_val ~= b_val then
      return a_val > b_val and 1 or -1
    end
  end

  return 0
end

local function read_local_version(root)
  local version_path = root .. "/bin/kotlin-lsp/VERSION"
  if vim.fn.filereadable(version_path) ~= 1 then
    return nil
  end

  local lines = vim.fn.readfile(version_path)
  return normalize_version(lines[1] or "")
end

local function is_lsp_installed(root)
  local lsp_path = root .. "/bin/kotlin-lsp/kotlin-lsp.sh"
  return vim.fn.filereadable(lsp_path) == 1
end

local function resolve_plugin_root()
  local root = get_plugin_root()
  if is_lsp_installed(root) then
    return root
  end

  for _, rtp in ipairs(vim.api.nvim_list_runtime_paths()) do
    local candidate = rtp
    if is_lsp_installed(candidate) then
      return candidate
    end
  end

  return root
end

local function fetch_latest_version(callback)
  if vim.fn.executable("curl") ~= 1 then
    callback(nil, "curl not found")
    return
  end

  local url = "https://api.github.com/repos/Kotlin/kotlin-lsp/releases/latest"
  run_system({ "curl", "-s", "-H", "Accept: application/vnd.github+json", url }, {}, function(code, stdout, stderr)
    if code ~= 0 then
      callback(nil, stderr ~= "" and stderr or "curl failed")
      return
    end

    local ok, decoded = pcall(vim.json.decode, stdout)
    if not ok or type(decoded) ~= "table" then
      callback(nil, "failed to parse GitHub response")
      return
    end

    callback(normalize_version(decoded.tag_name or decoded.name), nil)
  end)
end

function M.check_lsp_update(opts)
  opts = opts or {}
  local root = opts.root_dir or resolve_plugin_root()
  local local_version = read_local_version(root)

  fetch_latest_version(function(latest_version, err)
    vim.schedule(function()
      if err then
        vim.notify("kotlin-lsp update check failed: " .. err, vim.log.levels.WARN)
        return
      end

      if not latest_version then
        vim.notify("kotlin-lsp update check failed: missing version", vim.log.levels.WARN)
        return
      end

      if not local_version then
        if is_lsp_installed(root) or vim.fn.executable('kotlin-lsp') == 1 then
          vim.notify(
            "kotlin-lsp installed but version unknown (latest: " .. latest_version .. ")",
            vim.log.levels.WARN
          )
          return
        end
        vim.notify("kotlin-lsp not installed (latest: " .. latest_version .. ")", vim.log.levels.WARN)
        return
      end

      local cmp = compare_versions(latest_version, local_version)
      if cmp and cmp > 0 then
        vim.notify(
          string.format("kotlin-lsp update available: %s -> %s", local_version, latest_version),
          vim.log.levels.INFO
        )
        return
      end

      if not opts.silent_when_up_to_date then
        vim.notify("kotlin-lsp is up to date (" .. local_version .. ")", vim.log.levels.INFO)
      end
    end)
  end)
end

function M.install_latest()
  local root = resolve_plugin_root()
  local script = root .. "/scripts/install-lsp.sh"

  if vim.fn.filereadable(script) ~= 1 then
    vim.notify("install script not found: " .. script, vim.log.levels.ERROR)
    return
  end

  vim.notify("kotlin-lsp install started...", vim.log.levels.INFO)
  run_system({ script, "--latest", "--force" }, { cwd = root }, function(code, _, stderr)
    vim.schedule(function()
      if code ~= 0 then
        local msg = stderr ~= "" and stderr or "install failed"
        vim.notify("kotlin-lsp install failed: " .. msg, vim.log.levels.ERROR)
        return
      end

      local new_version = read_local_version(root)
      vim.notify(
        "kotlin-lsp installed" .. (new_version and (" (" .. new_version .. ")") or ""),
        vim.log.levels.INFO
      )
    end)
  end)
end

-- Kotlin LSPを停止
function M.stop_lsp(opts)
  opts = opts or {}
  local stopped = utils.stop_kotlin_lsp_clients({ force = opts.force })
  if stopped == 0 then
    vim.notify('kotlin-lsp client not found', vim.log.levels.WARN)
    return
  end

  vim.notify('kotlin-lsp stopped (' .. stopped .. ')', vim.log.levels.INFO)
end

-- Kotlin LSPを再起動
function M.restart_lsp()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  M.stop_lsp({ force = true })

  if filetype ~= 'kotlin' then
    vim.notify('Open a Kotlin buffer to restart kotlin-lsp', vim.log.levels.WARN)
    return
  end

  vim.schedule(function()
    vim.api.nvim_exec_autocmds('FileType', { buffer = bufnr, pattern = 'kotlin' })
  end)
end

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

  -- :KotlinLspCheckUpdate コマンド
  vim.api.nvim_create_user_command('KotlinLspCheckUpdate', function()
    M.check_lsp_update({ silent_when_up_to_date = false })
  end, {
    desc = 'Check kotlin-lsp updates'
  })

  -- :KotlinLspInstallLatest コマンド
  vim.api.nvim_create_user_command('KotlinLspInstallLatest', function()
    M.install_latest()
  end, {
    desc = 'Install latest kotlin-lsp'
  })

  -- :KotlinStopLsp コマンド
  vim.api.nvim_create_user_command('KotlinStopLsp', function()
    M.stop_lsp({ force = true })
  end, {
    desc = 'Stop kotlin-lsp'
  })

  -- :KotlinRestartLsp コマンド
  vim.api.nvim_create_user_command('KotlinRestartLsp', function()
    M.restart_lsp()
  end, {
    desc = 'Restart kotlin-lsp'
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
