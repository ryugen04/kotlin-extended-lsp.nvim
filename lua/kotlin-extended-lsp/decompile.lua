-- decompile.lua
-- JAR/class file decompilation support

local M = {}

-- シンプルなキャッシュ
local cache = {}

-- デコンパイルしてバッファに表示
function M.decompile_and_show(uri, range)
  -- キャッシュチェック
  if cache[uri] then
    M.show_buffer(uri, cache[uri], range)
    return
  end

  -- kotlin/jarClassContents リクエスト
  local params = { textDocument = { uri = uri } }

  vim.lsp.buf_request(0, 'kotlin/jarClassContents', params, function(err, result)
    if err then
      vim.notify('Decompile failed: ' .. tostring(err), vim.log.levels.ERROR)
      return
    end

    if not result then
      vim.notify('No decompiled content returned', vim.log.levels.WARN)
      return
    end

    -- キャッシュに保存
    cache[uri] = result

    -- バッファに表示
    M.show_buffer(uri, result, range)
  end)
end

-- デコンパイル結果をバッファに表示
function M.show_buffer(uri, content, range)
  -- 新しいバッファを作成
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- コンテンツを設定
  local lines = vim.split(content, '\n')
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- バッファ設定
  vim.api.nvim_buf_set_name(bufnr, uri)
  vim.bo[bufnr].filetype = 'kotlin'
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].buftype = 'nofile'

  -- バッファを表示
  vim.api.nvim_set_current_buf(bufnr)

  -- 範囲が指定されている場合はジャンプ
  if range and range.start then
    local line = range.start.line + 1  -- 0-indexed to 1-indexed
    local col = range.start.character
    vim.api.nvim_win_set_cursor(0, { line, col })
  end

  vim.notify('Decompiled: ' .. vim.fn.fnamemodify(uri, ':t'), vim.log.levels.INFO)
end

-- キャッシュクリア
function M.clear_cache()
  cache = {}
  vim.notify('Decompile cache cleared', vim.log.levels.INFO)
end

return M
