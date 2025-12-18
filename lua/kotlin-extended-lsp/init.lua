-- kotlin-extended-lsp.nvim
local M = {}
local utils = require('kotlin-extended-lsp.utils')

-- プラグインのルートディレクトリを取得
local function get_plugin_root()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  -- lua/kotlin-extended-lsp/init.lua から plugin root へ
  return vim.fn.fnamemodify(source, ":h:h:h")
end

-- kotlin-lsp実行ファイルのパスを取得
local function get_lsp_cmd()
  local plugin_root = get_plugin_root()
  local lsp_script = plugin_root .. "/bin/kotlin-lsp/kotlin-lsp.sh"

  if vim.fn.filereadable(lsp_script) == 1 then
    return lsp_script
  end

  -- システムのPATHから探す
  if vim.fn.executable('kotlin-lsp') == 1 then
    return 'kotlin-lsp'
  end

  return nil
end

local function build_lsp_cmd(lsp_cmd, opts)
  opts = opts or {}

  if opts.cmd then
    if type(opts.cmd) == 'string' then
      return { opts.cmd }
    end
    return opts.cmd
  end

  if type(lsp_cmd) == 'table' then
    return lsp_cmd
  end

  local cmd = { lsp_cmd, '--stdio' }

  -- VSCode相当の --system-path オプションを追加
  -- これがないとkotlin-lspがワークスペースを正しくインデックス化できない
  local system_path = opts.system_path
  if system_path == nil then
    -- デフォルト: ~/.local/state/nvim/kotlin-lsp
    system_path = vim.fn.stdpath('state') .. '/kotlin-lsp'
  end
  if system_path and system_path ~= '' then
    vim.fn.mkdir(system_path, 'p')
    table.insert(cmd, '--system-path')
    table.insert(cmd, system_path)
  end

  if opts.lsp_args then
    for _, arg in ipairs(opts.lsp_args) do
      table.insert(cmd, arg)
    end
  end

  return cmd
end

local function find_upwards(patterns, startpath)
  local found = vim.fs.find(patterns, {
    upward = true,
    path = startpath
  })

  if #found == 0 then
    return nil
  end

  return vim.fs.dirname(found[1])
end

local function detect_root_dir(buf_name, opts)
  if opts.root_dir then
    if type(opts.root_dir) == 'function' then
      return opts.root_dir(buf_name)
    end
    return opts.root_dir
  end

  local buf_dir = vim.fs.dirname(buf_name)
  local root_dir = find_upwards({ 'settings.gradle.kts', 'settings.gradle' }, buf_dir)
  if root_dir then
    return root_dir
  end

  root_dir = find_upwards({ 'build.gradle.kts', 'build.gradle', 'pom.xml' }, buf_dir)
  if root_dir then
    return root_dir
  end

  return find_upwards({ '.git' }, buf_dir)
end

local function build_cmd_env(opts)
  local env = opts.cmd_env or opts.env
  if env then
    return env
  end

  if opts.pass_github_env == false then
    return nil
  end

  local github_env = {}
  local token = os.getenv('GITHUB_TOKEN')
  local user = os.getenv('GITHUB_USER')
  if token and token ~= '' then
    github_env.GITHUB_TOKEN = token
  end
  if user and user ~= '' then
    github_env.GITHUB_USER = user
  end

  if next(github_env) then
    return github_env
  end

  return nil
end

local function ensure_cache_dir(path)
  if not path or path == '' then
    return
  end

  if vim.fn.isdirectory(path) == 1 then
    return
  end

  local ok = vim.fn.mkdir(path, 'p')
  if ok == 0 then
    vim.notify('Failed to create kotlin-lsp cache dir: ' .. path, vim.log.levels.WARN)
  end
end

function M.setup(opts)
  opts = opts or {}

  -- kotlin-lspが利用可能かチェック
  local lsp_cmd = opts.lsp_cmd or get_lsp_cmd()

  if not lsp_cmd then
    vim.notify(
      'kotlin-lsp not found. Run: scripts/install-lsp.sh',
      vim.log.levels.ERROR
    )
    return
  end

  -- Treesitterパーサーの自動セットアップ（非同期・オプション）
  if opts.enable_ts_definition ~= false and opts.auto_install_treesitter ~= false then
    vim.schedule(function()
      local ts_setup = require('kotlin-extended-lsp.treesitter_setup')
      ts_setup.setup()
    end)
  end

  -- デコンパイル機能をセットアップ
  local decompile_opts = opts.decompile or {}
  if opts.enable_decompile ~= false then
    local decompile = require('kotlin-extended-lsp.features.decompile')
    decompile.setup(decompile_opts)
  end

  -- カスタムコマンド群をセットアップ
  local commands_opts = opts.commands or {}
  if opts.enable_commands ~= false then
    local commands = require('kotlin-extended-lsp.features.commands')
    commands.setup(commands_opts)
    if opts.check_lsp_update == nil or opts.check_lsp_update == true then
      commands.check_lsp_update({ silent_when_up_to_date = true })
    end
  end

  -- Treesitterベースのジャンプ機能をセットアップ（優先）
  -- これがgdとgyをオーバーライドし、LSPフォールバックを提供
  local ts_def_opts = opts.ts_definition or {}
  if opts.enable_ts_definition ~= false then
    local ts_definition = require('kotlin-extended-lsp.features.ts_definition')
    if ts_def_opts.prefer_lsp == nil then
      ts_def_opts.prefer_lsp = opts.prefer_lsp_definition ~= false
    end
    ts_definition.setup(ts_def_opts)
  end

  -- 型定義ジャンプ機能をセットアップ（LSPベース）
  -- Treesitterが有効な場合、これは直接呼ばれずフォールバックとして使用される
  local type_def_opts = opts.type_definition or {}
  if opts.enable_type_definition ~= false then
    local type_definition = require('kotlin-extended-lsp.features.type_definition')
    -- treesitterが有効な場合はキーマップを設定しない
    if opts.enable_ts_definition ~= false then
      type_def_opts.setup_keymaps = false
    end
    type_definition.setup(type_def_opts)
  end

  -- 実装ジャンプ機能をセットアップ
  local impl_opts = opts.implementation or {}
  if opts.enable_implementation ~= false then
    local implementation = require('kotlin-extended-lsp.features.implementation')
    implementation.setup(impl_opts)
  end

  -- 宣言ジャンプ機能をセットアップ
  local decl_opts = opts.declaration or {}
  if opts.enable_declaration ~= false then
    local declaration = require('kotlin-extended-lsp.features.declaration')
    declaration.setup(decl_opts)
  end

  -- テストランナー機能をセットアップ
  local test_runner_opts = opts.test_runner or {}
  if opts.enable_test_runner ~= false then
    local test_runner = require('kotlin-extended-lsp.features.test_runner')
    test_runner.setup(test_runner_opts)
  end

  -- リファクタリング機能をセットアップ
  local refactor_opts = opts.refactor or {}
  if opts.enable_refactor ~= false then
    local refactor = require('kotlin-extended-lsp.features.refactor')
    refactor.setup(refactor_opts)
  end

  -- Detektリンター統合をセットアップ
  local detekt_opts = opts.detekt or {}
  if opts.enable_detekt ~= false then
    local detekt = require('kotlin-extended-lsp.features.detekt')
    detekt.setup(detekt_opts)
  end

  -- FileTypeイベントでLSPを起動
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'kotlin',
    callback = function(ev)
      -- プロジェクトルートを検出
      local buf_name = vim.api.nvim_buf_get_name(ev.buf)
      local root_dir = detect_root_dir(buf_name, opts)

      if not root_dir or root_dir == '' then
        vim.notify('Kotlin project root not found', vim.log.levels.WARN)
        return
      end

      -- 起動最適化機能を使用
      local optimizer = require('kotlin-extended-lsp.features.startup_optimizer')

      -- すでに起動しているかチェック
      local existing_client = optimizer.is_lsp_running(root_dir)
      if existing_client then
        -- 既存のクライアントを再利用
        vim.lsp.buf_attach_client(ev.buf, existing_client.id)
        return
      end

      -- LSP設定
      local init_options = optimizer.get_optimized_init_options()
      if opts.prioritize_dependency_resolution ~= false then
        init_options.deferGradleSync = false
      end
      if opts.cache_directory then
        init_options.cacheDirectory = opts.cache_directory
      elseif opts.use_cache_directory == false then
        init_options.cacheDirectory = nil
      end
      if opts.init_options then
        init_options = vim.tbl_deep_extend('force', init_options, opts.init_options)
      end

      ensure_cache_dir(init_options.cacheDirectory)

      if opts.debug_init_options then
        local log_path = vim.fn.stdpath('state') .. '/kotlin-extended-lsp.log'
        vim.fn.writefile(
          { 'init_options: ' .. vim.inspect(init_options) },
          log_path,
          'a'
        )
        vim.notify('kotlin-lsp init_options logged: ' .. log_path, vim.log.levels.INFO)
      end

      local lsp_config = {
        name = 'kotlin-lsp',
        cmd = build_lsp_cmd(lsp_cmd, opts),
        cmd_env = build_cmd_env(opts),
        root_dir = root_dir,
        -- 最適化されたinitializationOptions
        init_options = init_options,
        settings = opts.settings,
        capabilities = opts.capabilities,
        on_attach = function(client, bufnr)
          vim.notify('kotlin-lsp ready!', vim.log.levels.INFO)

          -- 基本的なキーマップを設定
          -- 注: gd, gi, gyは各feature moduleでオーバーライドされる
          local keymap_opts = { buffer = bufnr, silent = true }
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, keymap_opts)
          vim.keymap.set('n', 'gr', function()
            if opts.use_telescope ~= false then
              local ok, builtin = pcall(require, 'telescope.builtin')
              if ok then
                builtin.lsp_references()
                return
              end
            end
            vim.lsp.buf.references()
          end, keymap_opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, keymap_opts)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, keymap_opts)

          -- シグネチャヘルプ（関数パラメータ情報の表示）
          vim.keymap.set('i', '<C-k>', vim.lsp.buf.signature_help, keymap_opts)

          if opts.on_attach then
            opts.on_attach(client, bufnr)
          end
        end,
        on_init = opts.on_init,
        on_exit = opts.on_exit,
      }

      -- 非同期起動（進捗表示付き）
      optimizer.start_lsp_async(lsp_config)
    end,
  })

  if opts.shutdown_on_exit ~= false then
    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspShutdown', { clear = true }),
      callback = function()
        utils.stop_kotlin_lsp_clients({ force = true })
      end,
      desc = 'Shutdown kotlin-lsp on exit',
    })
  end

  vim.notify('kotlin-extended-lsp loaded: ' .. lsp_cmd, vim.log.levels.INFO)
end

return M
