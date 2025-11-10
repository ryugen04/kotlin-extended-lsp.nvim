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
          local opts = { buffer = bufnr, silent = true }
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        end,
      })
    end,
  })

  vim.notify('kotlin-extended-lsp loaded: ' .. lsp_cmd, vim.log.levels.INFO)
end

return M
