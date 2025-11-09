-- formatter.lua
-- Formatter integration manager

local M = {}

local config = require('kotlin-extended-lsp.config')
local logger = require('kotlin-extended-lsp.logger')

-- Registered formatters
M._formatters = {}

--- Register a formatter
--- @param name string Formatter name
--- @param formatter table Formatter implementation
function M.register(name, formatter)
  if not formatter.format and not formatter.format_buffer then
    error(string.format('Formatter %s must implement format() or format_buffer() function', name))
  end

  M._formatters[name] = formatter
  logger.debug('Registered formatter', { name = name })
end

--- Get a registered formatter
--- @param name string Formatter name
--- @return table|nil Formatter implementation or nil
function M.get_formatter(name)
  return M._formatters[name]
end

--- Check if a formatter is available
--- @param name string Formatter name
--- @return boolean
function M.is_available(name)
  local formatter = M._formatters[name]
  if not formatter then
    return false
  end

  if formatter.is_available then
    return formatter.is_available('format')
  end

  return true
end

--- Get the preferred formatter
--- @return string|nil Formatter name or nil
local function get_preferred_formatter()
  local cfg = config.get_value('formatting')
  if not cfg or not cfg.enabled then
    return nil
  end

  local prefer = cfg.prefer_formatter
  if prefer == 'none' then
    return nil
  end

  -- Check if preferred formatter is available
  if prefer == 'lsp' then
    return 'lsp'
  end

  if prefer and M.is_available(prefer) then
    local tool_cfg = cfg.tools[prefer]
    if tool_cfg and tool_cfg.enabled then
      return prefer
    end
  end

  -- Fallback: find first available formatter
  for name, tool_cfg in pairs(cfg.tools) do
    if tool_cfg.enabled and M.is_available(name) then
      return name
    end
  end

  return nil
end

--- Format using LSP
--- @param bufnr number Buffer number
--- @param callback function Callback (err)
local function format_with_lsp(bufnr, callback)
  local params = vim.lsp.util.make_formatting_params({})

  vim.lsp.buf_request(bufnr, 'textDocument/formatting', params, function(err, result, ctx, _)
    if err then
      callback('LSP formatting failed: ' .. err)
      return
    end

    if result then
      vim.lsp.util.apply_text_edits(result, bufnr, 'utf-8')
      logger.debug('LSP formatting completed')
      callback(nil)
    else
      callback('No formatting result from LSP')
    end
  end)
end

--- Format a buffer
--- @param bufnr number|nil Buffer number (default: current buffer)
--- @param formatter_name string|nil Specific formatter to use (default: preferred)
--- @param callback function|nil Callback (err)
function M.format(bufnr, formatter_name, callback)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  callback = callback or function() end

  -- Check if buffer is a Kotlin file
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  if filetype ~= 'kotlin' then
    callback('Not a Kotlin file')
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' then
    callback('Buffer has no file path')
    return
  end

  -- Determine formatter to use
  local formatter_to_use = formatter_name or get_preferred_formatter()
  if not formatter_to_use then
    callback('No formatter available')
    return
  end

  logger.debug('Formatting buffer', { buffer = bufnr, formatter = formatter_to_use })

  -- Use LSP formatter
  if formatter_to_use == 'lsp' then
    format_with_lsp(bufnr, callback)
    return
  end

  -- Use external formatter
  local formatter = M._formatters[formatter_to_use]
  if not formatter then
    callback(string.format('Formatter %s not registered', formatter_to_use))
    return
  end

  -- Prefer format_buffer if available
  if formatter.format_buffer then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    formatter.format_buffer(bufnr, lines, function(err, formatted_lines)
      if err then
        callback(err)
        return
      end

      if formatted_lines then
        -- Apply formatted content
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted_lines)
        logger.info('Buffer formatted', { formatter = formatter_to_use })
      end

      callback(nil)
    end)
  elseif formatter.format then
    -- Format file directly
    formatter.format(bufnr, filepath, function(err, formatted_content)
      if err then
        callback(err)
        return
      end

      if formatted_content then
        -- Reload buffer
        vim.cmd('checktime')
        logger.info('File formatted', { formatter = formatter_to_use })
      end

      callback(nil)
    end)
  else
    callback('Formatter has no format method')
  end
end

--- Format buffer range
--- @param bufnr number Buffer number
--- @param start_line number Start line (1-indexed)
--- @param end_line number End line (1-indexed)
--- @param callback function Callback (err)
function M.format_range(bufnr, start_line, end_line, callback)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  callback = callback or function() end

  -- Currently only LSP supports range formatting
  local params = vim.lsp.util.make_given_range_params(nil, nil, start_line, end_line)

  vim.lsp.buf_request(bufnr, 'textDocument/rangeFormatting', params, function(err, result, ctx, _)
    if err then
      callback('LSP range formatting failed: ' .. err)
      return
    end

    if result then
      vim.lsp.util.apply_text_edits(result, bufnr, 'utf-8')
      logger.debug('LSP range formatting completed')
      callback(nil)
    else
      callback('No formatting result from LSP')
    end
  end)
end

--- Setup formatting for a buffer
--- @param bufnr number Buffer number
function M.setup_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cfg = config.get_value('formatting')
  if not cfg or not cfg.enabled then
    return
  end

  local group = vim.api.nvim_create_augroup('KotlinExtendedLspFormatter_' .. bufnr, { clear = true })

  -- Format on save
  if cfg.on_save then
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      buffer = bufnr,
      callback = function()
        M.format(bufnr, nil, function(err)
          if err then
            logger.warn('Format on save failed', { error = err })
          end
        end)
      end,
    })
  end

  logger.debug('Formatter buffer setup complete', { buffer = bufnr })
end

--- Teardown formatting for a buffer
--- @param bufnr number Buffer number
function M.teardown_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ok = pcall(vim.api.nvim_del_augroup_by_name, 'KotlinExtendedLspFormatter_' .. bufnr)
  if ok then
    logger.debug('Formatter buffer teardown complete', { buffer = bufnr })
  end
end

--- Get formatter status
--- @return table Status information
function M.status()
  local cfg = config.get_value('formatting')
  local status = {
    enabled = cfg and cfg.enabled or false,
    prefer_formatter = cfg and cfg.prefer_formatter or 'none',
    formatters = {},
  }

  if cfg then
    for name, tool_cfg in pairs(cfg.tools) do
      status.formatters[name] = {
        enabled = tool_cfg.enabled,
        available = M.is_available(name),
      }
    end
  end

  return status
end

return M
