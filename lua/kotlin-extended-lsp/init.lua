-- init.lua
-- kotlin-extended-lsp.nvim - Minimal LSP integration with decompile support

local M = {}

-- 簡易設定ストレージ
M._config = {}
M._initialized = false

-- デフォルト設定
local DEFAULT_CONFIG = {
  lsp = {
    cmd = {
      'kotlin-lsp',
      '--stdio',
      '--jvm-arg=-Xms512m',
      '--jvm-arg=-Xmx2g',
      '--jvm-arg=-XX:+UseG1GC',
      '--jvm-arg=-XX:+UseStringDeduplication',
      '--jvm-arg=-XX:MaxGCPauseMillis=200',
    },
    root_patterns = {
      'settings.gradle.kts',
      'settings.gradle',
      'build.gradle.kts',
      'build.gradle',
      'pom.xml',
      '.git',
    },
  },
  decompile = {
    auto_decompile = true,  -- JAR/classファイルへのジャンプ時に自動デコンパイル
  },
}

-- 設定のマージ
local function merge_config(user_config)
  user_config = user_config or {}
  M._config = vim.tbl_deep_extend('force', DEFAULT_CONFIG, user_config)
end

-- セットアップ
function M.setup(user_config)
  if M._initialized then
    vim.notify('kotlin-extended-lsp already initialized', vim.log.levels.WARN)
    return
  end

  merge_config(user_config)

  -- lspconfigを使用してkotlin-lspを設定
  local ok, lspconfig = pcall(require, 'lspconfig')
  if not ok then
    vim.notify('nvim-lspconfig not found', vim.log.levels.ERROR)
    return
  end

  local lspconfig_configs = require('lspconfig.configs')

  -- kotlin_lsp設定が存在しない場合は登録
  if not lspconfig_configs.kotlin_lsp then
    lspconfig_configs.kotlin_lsp = {
      default_config = {
        cmd = M._config.lsp.cmd,
        filetypes = { 'kotlin' },
        root_dir = lspconfig.util.root_pattern(unpack(M._config.lsp.root_patterns)),
        settings = {},
      },
    }
  end

  -- kotlin-lspのセットアップ
  lspconfig.kotlin_lsp.setup({
    autostart = true,  -- 自動起動を明示的に有効化
    cmd = M._config.lsp.cmd,  -- コマンドを明示的に設定
    root_dir = lspconfig.util.root_pattern(unpack(M._config.lsp.root_patterns)),
    on_attach = function(client, bufnr)
      vim.notify('kotlin-lsp attached to buffer ' .. bufnr, vim.log.levels.INFO)

      -- デコンパイル対応のハンドラーをセットアップ
      if M._config.decompile.auto_decompile then
        require('kotlin-extended-lsp.handlers').setup_extended_handlers(bufnr)
      end
    end,
  })

  M._initialized = true
  vim.notify('kotlin-extended-lsp initialized', vim.log.levels.INFO)
end

return M
