-- Treesitterパーサーの自動セットアップ
local M = {}

-- Kotlinパーサーがインストールされているかチェック
function M.is_parser_installed()
  local ok = pcall(vim.treesitter.language.add, 'kotlin')
  return ok
end

-- Kotlinパーサーを自動インストール
function M.ensure_parser_installed()
  -- nvim-treesitterがインストールされているか確認
  local has_ts_config, ts_config = pcall(require, 'nvim-treesitter.configs')
  if not has_ts_config then
    vim.notify(
      'nvim-treesitter not found. Install it for better performance:\n' ..
      '  :Lazy install nvim-treesitter',
      vim.log.levels.WARN
    )
    return false
  end

  -- Kotlinパーサーがインストールされているか確認
  if M.is_parser_installed() then
    return true
  end

  -- パーサーをバックグラウンドでインストール
  vim.notify('Installing Kotlin treesitter parser...', vim.log.levels.INFO)

  -- nvim-treesitter.installを使用して非同期インストール
  local has_install, ts_install = pcall(require, 'nvim-treesitter.install')
  if not has_install then
    vim.notify(
      'Failed to load nvim-treesitter.install',
      vim.log.levels.ERROR
    )
    return false
  end

  -- 非同期でインストール
  vim.schedule(function()
    ts_install.update({ with_sync = false })('kotlin')

    -- インストール完了を待ってから通知
    vim.defer_fn(function()
      if M.is_parser_installed() then
        vim.notify(
          'Kotlin treesitter parser installed successfully!',
          vim.log.levels.INFO
        )
      else
        vim.notify(
          'Failed to install Kotlin parser. You can install it manually:\n' ..
          '  :TSInstall kotlin',
          vim.log.levels.WARN
        )
      end
    end, 3000)
  end)

  return false  -- まだインストール中
end

-- セットアップ: プラグイン初期化時に呼び出される
function M.setup()
  -- nvim-treesitterが利用可能な場合のみ実行
  local has_ts = pcall(require, 'nvim-treesitter')
  if not has_ts then
    return false
  end

  -- パーサーが既にインストールされていればOK
  if M.is_parser_installed() then
    return true
  end

  -- インストールされていない場合、自動インストールを試みる
  M.ensure_parser_installed()
  return false
end

return M
