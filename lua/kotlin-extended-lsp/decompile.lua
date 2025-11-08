-- decompile.lua
-- JAR/class file decompilation with caching and error handling

local logger = require('kotlin-extended-lsp.logger')
local config = require('kotlin-extended-lsp.config')
local lsp_client = require('kotlin-extended-lsp.lsp_client')

local M = {}

-- Decompile cache
local cache = {}
local cache_timestamps = {}

-- Check if URI is a compiled file
function M.is_compiled_file(uri)
  if not uri or type(uri) ~= 'string' then
    return false
  end

  return uri:match("%.class$") ~= nil or uri:match("jar:file:") ~= nil
end

-- Clean cache entry if expired
local function clean_cache_entry(uri)
  if not cache[uri] then
    return
  end

  local cache_ttl = config.get_value('performance.cache_ttl')
  local timestamp = cache_timestamps[uri]

  if not timestamp or (os.time() - timestamp) > cache_ttl then
    logger.debug('Cache entry expired', { uri = uri })
    cache[uri] = nil
    cache_timestamps[uri] = nil
    return true
  end

  return false
end

-- Get from cache
local function get_from_cache(uri)
  if not config.get_value('performance.cache_enabled') then
    return nil
  end

  clean_cache_entry(uri)
  return cache[uri]
end

-- Store in cache
local function store_in_cache(uri, content)
  if not config.get_value('performance.cache_enabled') then
    return
  end

  cache[uri] = content
  cache_timestamps[uri] = os.time()
  logger.debug('Stored in cache', { uri = uri, size = #content })
end

-- Clear cache
function M.clear_cache()
  local count = vim.tbl_count(cache)
  cache = {}
  cache_timestamps = {}
  logger.info(string.format('Cleared cache (%d entries)', count))
end

-- Create decompiled buffer
local function create_decompiled_buffer(uri, content)
  -- Check file size limit
  local max_size = config.get_value('performance.max_file_size')
  if #content > max_size then
    local err_msg = string.format(
      'Decompiled content too large (%d bytes, max: %d bytes)',
      #content,
      max_size
    )
    logger.warn(err_msg, { uri = uri })
    return nil, err_msg
  end

  -- Search for existing buffer
  local existing_bufnr = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      if buf_name == uri then
        existing_bufnr = bufnr
        break
      end
    end
  end

  local bufnr
  if existing_bufnr then
    bufnr = existing_bufnr
    -- Make buffer temporarily modifiable
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  else
    -- Create new scratch buffer
    bufnr = vim.api.nvim_create_buf(false, true)
    if bufnr == 0 then
      return nil, 'Failed to create buffer'
    end
    vim.api.nvim_buf_set_name(bufnr, uri)
  end

  -- Set content
  local lines = vim.split(content, '\n', { plain = true })
  local ok, err = pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, lines)
  if not ok then
    logger.error('Failed to set buffer lines', { error = err, uri = uri })
    return nil, err
  end

  -- Set buffer options
  local show_line_numbers = config.get_value('decompile.show_line_numbers')
  local syntax_highlight = config.get_value('decompile.syntax_highlight')

  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(bufnr, 'readonly', true)
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')

  if syntax_highlight then
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'kotlin')
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
  local cached_content = get_from_cache(uri)
  if cached_content then
    logger.debug('Using cached decompiled content', { uri = uri })
    if callback then
      callback(nil, cached_content)
    end
    return
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
      store_in_cache(uri, result)

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
        vim.notify(
          'No definition found',
          vim.log.levels.WARN,
          { title = 'kotlin-extended-lsp' }
        )
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
