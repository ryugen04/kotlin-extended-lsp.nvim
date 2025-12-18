-- LSP起動最適化機能
-- kotlin-lspの初回起動を高速化するための最適化機能を提供

local M = {}

-- デバッグログ設定
local function log(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify('[LSP Optimizer] ' .. msg, level)
end

-- LSPクライアントがすでに起動しているかチェック
function M.is_lsp_running(root_dir)
  local clients = vim.lsp.get_clients({ name = 'kotlin-lsp' })

  for _, client in ipairs(clients) do
    if client.config.root_dir == root_dir then
      return client
    end
  end

  return nil
end

-- 起動進捗通知
local function show_startup_progress(root_dir)
  local progress_timer = nil
  local progress_dots = 0

  -- プログレスバーを表示
  progress_timer = vim.loop.new_timer()
  progress_timer:start(0, 500, vim.schedule_wrap(function()
    progress_dots = (progress_dots + 1) % 4
    local dots = string.rep('.', progress_dots)
    vim.notify(
      'kotlin-lsp initializing' .. dots .. ' (Gradle indexing may take a while)',
      vim.log.levels.INFO,
      { title = 'Kotlin LSP', replace = true, timeout = 500 }
    )
  end))

  -- LspAttachでタイマーを停止
  vim.api.nvim_create_autocmd('LspAttach', {
    pattern = '*.kt',
    once = true,
    callback = function()
      if progress_timer then
        progress_timer:stop()
        progress_timer:close()
      end
      vim.notify('kotlin-lsp ready!', vim.log.levels.INFO, { timeout = 1000 })
    end
  })
end

-- 非同期起動ラッパー
function M.start_lsp_async(config)
  local root_dir = config.root_dir

  -- すでに起動しているかチェック
  local existing_client = M.is_lsp_running(root_dir)
  if existing_client then
    log('Reusing existing LSP client for ' .. root_dir)
    return existing_client
  end

  -- 進捗通知を表示
  show_startup_progress(root_dir)

  -- LSPを非同期起動
  vim.schedule(function()
    vim.lsp.start(config)
  end)
end

-- ワークスペースキャッシュの場所を取得
function M.get_cache_dir()
  local home = os.getenv('HOME') or ''
  if home == '' then
    return nil
  end

  if vim.loop.os_uname().sysname == 'Darwin' then
    return home .. '/Library/Caches/kotlin-lsp'
  end

  local cache_home = os.getenv('XDG_CACHE_HOME') or (home .. '/.cache')
  return cache_home .. '/kotlin-lsp'
end

-- キャッシュクリア機能
function M.clear_cache()
  local cache_dir = M.get_cache_dir()

  vim.ui.select({'Yes', 'No'}, {
    prompt = 'Clear kotlin-lsp cache? This will slow down next startup.',
  }, function(choice)
    if choice == 'Yes' then
      vim.fn.system({'rm', '-rf', cache_dir})
      log('Cache cleared: ' .. cache_dir)
    end
  end)
end

-- JAVA_HOMEを検出
local function detect_java_home()
  -- 環境変数から取得
  local java_home = os.getenv('JAVA_HOME')
  if java_home and java_home ~= '' then
    return java_home
  end

  -- macOSの場合は /usr/libexec/java_home を使用
  if vim.loop.os_uname().sysname == 'Darwin' then
    local handle = io.popen('/usr/libexec/java_home 2>/dev/null')
    if handle then
      java_home = handle:read('*l')
      handle:close()
      if java_home and java_home ~= '' then
        return java_home
      end
    end
  end

  return nil
end

-- 初期化オプションの最適化
function M.get_optimized_init_options()
  local opts = {
    -- Gradle sync を遅延実行
    deferGradleSync = true,

    -- インデックス化を段階的に実行
    incrementalIndexing = true,
  }

  local cache_dir = M.get_cache_dir()
  if cache_dir then
    opts.cacheDirectory = cache_dir
  end

  -- VSCode相当: defaultJdk を設定（シンボル解決に使用）
  local java_home = detect_java_home()
  if java_home then
    opts.defaultJdk = java_home
  end

  return opts
end

return M
