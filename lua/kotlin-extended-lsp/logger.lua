-- logger.lua
-- Structured logging for kotlin-extended-lsp.nvim

local M = {}

-- Log levels
M.levels = {
  TRACE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
  OFF = 5,
}

-- Default configuration
local config = {
  level = M.levels.INFO,
  use_console = true,
  use_file = false,
  file_path = vim.fn.stdpath('cache') .. '/kotlin-extended-lsp.log',
  highlights = true,
}

-- Internal state
local log_file = nil

-- Initialize logger with config
function M.setup(opts)
  config = vim.tbl_deep_extend('force', config, opts or {})

  if config.use_file then
    log_file = io.open(config.file_path, 'a')
    if log_file then
      log_file:write(string.format('\n--- Session started: %s ---\n', os.date('%Y-%m-%d %H:%M:%S')))
      log_file:flush()
    end
  end
end

-- Format log message
local function format_message(level_name, msg, context)
  local timestamp = os.date('%H:%M:%S')
  local context_str = context and string.format(' [%s]', vim.inspect(context)) or ''
  return string.format('[%s] %s: %s%s', timestamp, level_name, msg, context_str)
end

-- Write to console
local function write_console(level, level_name, msg, context)
  if not config.use_console then
    return
  end

  local formatted = format_message(level_name, msg, context)
  local vim_level = vim.log.levels.INFO

  if level == M.levels.TRACE or level == M.levels.DEBUG then
    vim_level = vim.log.levels.DEBUG
  elseif level == M.levels.WARN then
    vim_level = vim.log.levels.WARN
  elseif level == M.levels.ERROR then
    vim_level = vim.log.levels.ERROR
  end

  vim.notify(formatted, vim_level, { title = 'kotlin-extended-lsp' })
end

-- Write to file
local function write_file(level_name, msg, context)
  if not config.use_file or not log_file then
    return
  end

  local formatted = format_message(level_name, msg, context)
  log_file:write(formatted .. '\n')
  log_file:flush()
end

-- Generic log function
local function log(level, level_name, msg, context)
  if level < config.level then
    return
  end

  write_console(level, level_name, msg, context)
  write_file(level_name, msg, context)
end

-- Public logging functions
function M.trace(msg, context)
  log(M.levels.TRACE, 'TRACE', msg, context)
end

function M.debug(msg, context)
  log(M.levels.DEBUG, 'DEBUG', msg, context)
end

function M.info(msg, context)
  log(M.levels.INFO, 'INFO', msg, context)
end

function M.warn(msg, context)
  log(M.levels.WARN, 'WARN', msg, context)
end

function M.error(msg, context)
  log(M.levels.ERROR, 'ERROR', msg, context)
end

-- Log LSP request/response
function M.lsp_request(method, params)
  M.debug(string.format('LSP Request: %s', method), { params = params })
end

function M.lsp_response(method, success, result_or_error)
  if success then
    M.debug(string.format('LSP Response: %s (success)', method), { result = result_or_error })
  else
    M.error(string.format('LSP Response: %s (error)', method), { error = result_or_error })
  end
end

-- Cleanup
function M.close()
  if log_file then
    log_file:write(string.format('--- Session ended: %s ---\n', os.date('%Y-%m-%d %H:%M:%S')))
    log_file:close()
    log_file = nil
  end
end

return M
