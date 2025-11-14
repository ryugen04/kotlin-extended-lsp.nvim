-- kotlin-extended-lsp.nvim
local M = {}

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

function M.setup(opts)
  opts = opts or {}

  -- kotlin-lspが利用可能かチェック
  local lsp_cmd = get_lsp_cmd()

  if not lsp_cmd then
    vim.notify(
      'kotlin-lsp not found. Run: scripts/install-lsp.sh',
      vim.log.levels.ERROR
    )
    return
  end

  -- Treesitterパーサーの自動セットアップ（オプション）
  if opts.enable_ts_definition ~= false and opts.auto_install_treesitter ~= false then
    local ts_setup = require('kotlin-extended-lsp.treesitter_setup')
    ts_setup.setup()
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
  end

  -- Treesitterベースのジャンプ機能をセットアップ（優先）
  -- これがgdとgyをオーバーライドし、LSPフォールバックを提供
  local ts_def_opts = opts.ts_definition or {}
  if opts.enable_ts_definition ~= false then
    local ts_definition = require('kotlin-extended-lsp.features.ts_definition')
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

  -- FileTypeイベントでLSPを起動
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'kotlin',
    callback = function(ev)
      -- プロジェクトルートを検出
      local root_patterns = {
        'settings.gradle.kts',
        'settings.gradle',
        'build.gradle.kts',
        'build.gradle',
        'pom.xml',
        '.git'
      }

      -- バッファのファイルパスから検索
      local buf_name = vim.api.nvim_buf_get_name(ev.buf)
      local found = vim.fs.find(root_patterns, {
        upward = true,
        path = vim.fs.dirname(buf_name)
      })

      if #found == 0 then
        vim.notify('Kotlin project root not found', vim.log.levels.WARN)
        return
      end

      local root_dir = vim.fs.dirname(found[1])

      -- LSPクライアントを起動
      vim.lsp.start({
        name = 'kotlin-lsp',
        cmd = { lsp_cmd, '--stdio' },
        root_dir = root_dir,
        on_attach = function(client, bufnr)
          vim.notify('kotlin-lsp attached to buffer ' .. bufnr, vim.log.levels.INFO)

          -- 基本的なキーマップを設定
          -- 注: gd, gi, gyは各feature moduleでオーバーライドされる
          local keymap_opts = { buffer = bufnr, silent = true }
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, keymap_opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, keymap_opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, keymap_opts)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, keymap_opts)
        end,
      })
    end,
  })

  vim.notify('kotlin-extended-lsp loaded: ' .. lsp_cmd, vim.log.levels.INFO)
end

return M
