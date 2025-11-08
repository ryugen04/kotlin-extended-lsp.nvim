-- decompile.lua
-- JAR/class file decompilation with caching and error handling

local cache = require('kotlin-extended-lsp.cache')
local config = require('kotlin-extended-lsp.config')
local logger = require('kotlin-extended-lsp.logger')
local lsp_client = require('kotlin-extended-lsp.lsp_client')

local M = {}

-- Initialize cache with configuration
local function init_cache()
  local perf_config = config.get_value('performance')
  cache.setup({
    max_size = perf_config.max_cache_entries or 50,
    ttl = perf_config.cache_ttl or 3600,
  })
end

-- Check if URI is a compiled file
function M.is_compiled_file(uri)
  if not uri or type(uri) ~= 'string' then
    return false
  end

  -- URI長の制限（DoS対策）
  if #uri > 4096 then
    logger.warn('URI too long, rejecting', { length = #uri })
    return false
  end

  -- パストラバーサル攻撃対策
  if uri:match('%.%.') then
    logger.warn('Path traversal attempt detected', { uri = uri })
    return false
  end

  -- 不正な文字の検出（すべての制御文字を拒否）
  for i = 1, #uri do
    local byte = uri:byte(i)
    -- 0x00-0x1F の制御文字をすべて拒否
    if byte and byte <= 0x1F then
      logger.warn('Invalid control characters in URI', { uri = uri })
      return false
    end
  end

  -- スキーム検証（許可されたスキームのみ）
  local valid_schemes = { 'jar:file:', 'file:' }
  local has_valid_scheme = false
  for _, scheme in ipairs(valid_schemes) do
    if uri:sub(1, #scheme) == scheme then
      has_valid_scheme = true
      break
    end
  end

  if not has_valid_scheme then
    logger.debug('Invalid URI scheme', { uri = uri })
    return false
  end

  -- クラスファイル拡張子の確認
  return uri:match('%.class$') ~= nil or uri:match('jar:file:.*%.class$') ~= nil
end

-- Clear cache
function M.clear_cache()
  local count = cache.clear()
  logger.info(string.format('Cleared cache (%d entries)', count))
end

-- Get cache statistics
function M.cache_stats()
  return cache.stats()
end

-- Clean expired cache entries
function M.clean_cache()
  local removed = cache.clean_expired()
  logger.info(string.format('Cleaned %d expired cache entries', removed))
  return removed
end

-- Create decompiled buffer
local function create_decompiled_buffer(uri, content)
  -- Check file size limit
  local max_size = config.get_value('performance.max_file_size')
  if #content > max_size then
    local err_msg =
      string.format('Decompiled content too large (%d bytes, max: %d bytes)', #content, max_size)
    logger.warn(err_msg, { uri = uri })
    return nil, err_msg
  end

  -- Search for existing buffer（競合状態対策でpcall使用）
  local existing_bufnr = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local ok, valid = pcall(vim.api.nvim_buf_is_valid, bufnr)
    if ok and valid then
      local ok2, buf_name = pcall(vim.api.nvim_buf_get_name, bufnr)
      if ok2 and buf_name == uri then
        existing_bufnr = bufnr
        break
      end
    end
  end

  local bufnr
  if existing_bufnr then
    bufnr = existing_bufnr
    -- Make buffer temporarily modifiable（Neovim 0.10対応）
    local ok = pcall(function()
      vim.bo[bufnr].modifiable = true
    end)
    if not ok then
      logger.error('Failed to make buffer modifiable', { bufnr = bufnr, uri = uri })
      return nil, 'Failed to modify buffer options'
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  else
    -- Create new scratch buffer
    bufnr = vim.api.nvim_create_buf(false, true)
    if bufnr == 0 then
      return nil, 'Failed to create buffer'
    end
    local ok, err = pcall(vim.api.nvim_buf_set_name, bufnr, uri)
    if not ok then
      logger.error('Failed to set buffer name', { error = err, uri = uri })
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      return nil, err
    end
  end

  -- Set content（エラー時はロールバック）
  local lines = vim.split(content, '\n', { plain = true })
  local ok, err = pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, lines)
  if not ok then
    logger.error('Failed to set buffer lines', { error = err, uri = uri })
    if not existing_bufnr then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
    return nil, err
  end

  -- Set buffer options（Neovim 0.10対応）
  local show_line_numbers = config.get_value('decompile.show_line_numbers')
  local syntax_highlight = config.get_value('decompile.syntax_highlight')

  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = 'hide'

  if syntax_highlight then
    vim.bo[bufnr].filetype = 'kotlin'
  end

  -- Set buffer-local keymaps for easy navigation
  vim.api.nvim_buf_set_keymap(
    bufnr,
    'n',
    'q',
    '<cmd>bd<CR>',
    { noremap = true, silent = true, desc = 'Close decompiled buffer' }
  )

  -- Add signs to indicate decompiled file
  local sign = config.get_value('ui.signs.decompiled')
  if sign and sign ~= '' then
    vim.fn.sign_define('KotlinDecompiled', { text = sign, texthl = 'Comment' })
    vim.fn.sign_place(0, 'kotlin-extended-lsp', 'KotlinDecompiled', bufnr, { lnum = 1 })
  end

  return bufnr, nil
end

-- Show decompiled content
function M.show_decompiled(uri, content, opts)
  opts = opts or {}

  local bufnr, err = create_decompiled_buffer(uri, content)
  if not bufnr then
    logger.error('Failed to create decompiled buffer', { error = err, uri = uri })
    return nil, err
  end

  -- Display buffer
  if not opts.no_focus then
    vim.api.nvim_set_current_buf(bufnr)
  end

  -- Show notification
  if not opts.silent then
    local silent_fallbacks = config.get_value('silent_fallbacks')
    if not silent_fallbacks then
      vim.notify(
        string.format('Decompiled: %s', vim.fn.fnamemodify(uri, ':t')),
        vim.log.levels.INFO,
        { title = 'kotlin-extended-lsp' }
      )
    end
  end

  logger.info('Decompiled file displayed', { uri = uri, bufnr = bufnr })
  return bufnr, nil
end

-- Decompile URI using kotlin-lsp
function M.decompile_uri(uri, callback)
  if not M.is_compiled_file(uri) then
    local err_msg = 'Not a compiled file'
    logger.debug(err_msg, { uri = uri })
    if callback then
      callback(err_msg, nil)
    end
    return
  end

  -- Check cache first
  if config.get_value('performance.cache_enabled') then
    local cached_content = cache.get(uri)
    if cached_content then
      logger.debug('Using cached decompiled content', { uri = uri })
      if callback then
        callback(nil, cached_content)
      end
      return
    end
  end

  -- Check if custom command is supported
  if not lsp_client.supports_custom_command('kotlin/jarClassContents') then
    local err_msg = 'kotlin/jarClassContents command not supported by LSP'
    logger.error(err_msg)
    if callback then
      callback(err_msg, nil)
    end
    return
  end

  logger.info('Decompiling URI', { uri = uri })

  -- Make LSP request
  lsp_client.request(
    'kotlin/jarClassContents',
    { textDocument = { uri = uri } },
    function(err, result)
      if err then
        logger.error('Decompile failed', { error = err, uri = uri })
        if callback then
          callback(err, nil)
        end
        return
      end

      if not result or result == '' then
        local err_msg = 'Decompile returned empty result'
        logger.warn(err_msg, { uri = uri })
        if callback then
          callback(err_msg, nil)
        end
        return
      end

      -- Store in cache
      if config.get_value('performance.cache_enabled') then
        cache.put(uri, result)
      end

      logger.info('Decompile successful', { uri = uri, size = #result })
      if callback then
        callback(nil, result)
      end
    end
  )
end

-- Handle definition result with decompile support
function M.handle_definition_result(err, result, ctx, lsp_config, opts)
  opts = opts or {}

  if err then
    logger.error('Definition request failed', { error = err })
    if not opts.silent then
      vim.notify(
        string.format('Definition lookup failed: %s', err),
        vim.log.levels.ERROR,
        { title = 'kotlin-extended-lsp' }
      )
    end
    return
  end

  if not result or vim.tbl_isempty(result) then
    if not opts.silent then
      local silent_fallbacks = config.get_value('silent_fallbacks')
      if not silent_fallbacks then
        vim.notify('No definition found', vim.log.levels.WARN, { title = 'kotlin-extended-lsp' })
      end
    end
    return
  end

  local location = result[1]
  local uri = location.uri or location.targetUri

  if M.is_compiled_file(uri) then
    -- Compiled file - attempt decompile
    if config.get_value('decompile_on_jar') then
      M.decompile_uri(uri, function(decompile_err, content)
        if decompile_err then
          -- Decompile failed, use standard handler
          logger.warn('Decompile failed, using standard handler', { error = decompile_err })
          vim.lsp.handlers['textDocument/definition'](err, result, ctx, lsp_config)
          return
        end

        M.show_decompiled(uri, content, opts)
      end)
    else
      -- Decompile disabled, use standard handler
      vim.lsp.handlers['textDocument/definition'](err, result, ctx, lsp_config)
    end
  else
    -- Source file - use standard handler
    vim.lsp.handlers['textDocument/definition'](err, result, ctx, lsp_config)
  end
end

return M
