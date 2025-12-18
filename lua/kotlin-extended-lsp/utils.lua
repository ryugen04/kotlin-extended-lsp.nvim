-- 共通ユーティリティ関数

local M = {}

-- kotlin-lspクライアントを取得
function M.get_kotlin_lsp_client(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = 'kotlin-lsp' })

  if #clients == 0 then
    return nil, 'kotlin-lsp client not found'
  end

  return clients[1], nil
end

-- kotlin-lspクライアント一覧を取得
function M.get_kotlin_lsp_clients(opts)
  opts = opts or {}
  local filter = vim.tbl_extend('force', { name = 'kotlin-lsp' }, opts)
  return vim.lsp.get_clients(filter)
end

-- kotlin-lspクライアントを停止
function M.stop_kotlin_lsp_clients(opts)
  opts = opts or {}
  local clients = M.get_kotlin_lsp_clients(opts)
  local stopped = 0

  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id, opts.force)
    stopped = stopped + 1
  end

  return stopped
end

-- LSP workspace/executeCommand を実行
function M.execute_command(command, arguments, callback)
  local client, err = M.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local params = {
    command = command,
    arguments = arguments or {}
  }

  local success, request_id = client.request('workspace/executeCommand', params, function(err, result)

    if err then
      vim.notify('Command execution failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
      if callback then
        callback(nil, err)
      end
      return
    end

    -- resultが有効か確認
    if result == nil then
      vim.notify('Command returned no result', vim.log.levels.WARN)
      if callback then
        callback(nil, 'No result')
      end
      return
    end

    if callback then
      callback(result, nil)
    end
  end)

  if not success then
    vim.notify('Failed to send LSP request', vim.log.levels.ERROR)
    return false
  end

  return true, request_id
end

-- カーソル位置のシンボル情報を取得
function M.get_symbol_under_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params()

  return params
end

-- URIをファイルパスに変換
function M.uri_to_path(uri)
  return vim.uri_to_fname(uri)
end

-- ファイルパスをURIに変換
function M.path_to_uri(path)
  return vim.uri_from_fname(path)
end

-- 読み取り専用バッファを作成
function M.create_readonly_buffer(name, content, filetype)
  local buf = vim.api.nvim_create_buf(false, true)

  -- バッファ名を設定
  vim.api.nvim_buf_set_name(buf, name)

  -- コンテンツを設定（一時的にmodifiableにする）
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, '\n'))

  -- バッファオプションを設定（非推奨APIを使用しない）
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  vim.bo[buf].bufhidden = 'hide'

  if filetype then
    vim.bo[buf].filetype = filetype
  end

  return buf
end

-- 新しいウィンドウでバッファを開く
function M.open_buffer_in_split(buf, split_type)
  split_type = split_type or 'vertical'

  if split_type == 'vertical' then
    vim.cmd('vsplit')
  elseif split_type == 'horizontal' then
    vim.cmd('split')
  elseif split_type == 'tab' then
    vim.cmd('tabnew')
  end

  vim.api.nvim_win_set_buf(0, buf)
end

return M
