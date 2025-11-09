-- tools/ktfmt.lua
-- ktfmt formatter integration

local M = {}

local config = require('kotlin-extended-lsp.config')
local job = require('kotlin-extended-lsp.utils.job')
local logger = require('kotlin-extended-lsp.logger')

--- Find ktfmt executable
--- @return string|nil
local function find_ktfmt()
  local cfg = config.get_value('formatting.tools.ktfmt')
  if cfg and cfg.cmd then
    return cfg.cmd
  end

  -- Try standalone ktfmt
  return job.find_executable('ktfmt')
end

--- Check if ktfmt is available
--- @param mode string 'format'
--- @return boolean
function M.is_available(mode)
  return find_ktfmt() ~= nil
end

--- Format a file with ktfmt
--- @param bufnr number Buffer number
--- @param filepath string File path
--- @param callback function Callback (err, formatted_content)
function M.format(bufnr, filepath, callback)
  local cmd = find_ktfmt()
  if not cmd then
    callback('ktfmt not found', nil)
    return
  end

  local cfg = config.get_value('formatting.tools.ktfmt')

  local args = {}

  -- Style
  if cfg.style then
    if cfg.style == 'google' then
      table.insert(args, '--google-style')
    elseif cfg.style == 'kotlinlang' then
      table.insert(args, '--kotlinlang-style')
    elseif cfg.style == 'dropbox' then
      table.insert(args, '--dropbox-style')
    end
  end

  -- Max width
  if cfg.max_width then
    table.insert(args, '--max-width=' .. cfg.max_width)
  end

  -- File to format
  table.insert(args, filepath)

  logger.debug('Running ktfmt', { cmd = cmd, args = args })

  job.run(cmd, args, {
    timeout = 15000,
  }, function(err, stdout, stderr, code)
    if err then
      logger.warn('ktfmt failed', { error = err, stderr = stderr })
      callback(err, nil)
      return
    end

    -- ktfmt formats in-place, so we need to read the file
    local formatted_content = vim.fn.readfile(filepath)

    logger.debug('ktfmt completed')
    callback(nil, formatted_content)
  end)
end

--- Format buffer content (without writing to file)
--- @param bufnr number Buffer number
--- @param content table Buffer lines
--- @param callback function Callback (err, formatted_lines)
function M.format_buffer(bufnr, content, callback)
  local cmd = find_ktfmt()
  if not cmd then
    callback('ktfmt not found', nil)
    return
  end

  local cfg = config.get_value('formatting.tools.ktfmt')

  local args = {}

  -- Style
  if cfg.style then
    if cfg.style == 'google' then
      table.insert(args, '--google-style')
    elseif cfg.style == 'kotlinlang' then
      table.insert(args, '--kotlinlang-style')
    elseif cfg.style == 'dropbox' then
      table.insert(args, '--dropbox-style')
    end
  end

  -- Max width
  if cfg.max_width then
    table.insert(args, '--max-width=' .. cfg.max_width)
  end

  -- Read from stdin
  table.insert(args, '--stdin-name=stdin.kt')
  table.insert(args, '-')

  logger.debug('Running ktfmt on buffer', { cmd = cmd, args = args })

  -- Create input
  local input = table.concat(content, '\n')

  -- Use vim.system for stdin support (Neovim 0.10+)
  if vim.system then
    vim.system({ cmd, unpack(args) }, {
      stdin = input,
      text = true,
    }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          callback(result.stderr or 'ktfmt failed', nil)
        else
          local lines = vim.split(result.stdout, '\n', { plain = true })
          -- Remove trailing empty line if present
          if lines[#lines] == '' then
            table.remove(lines)
          end
          callback(nil, lines)
        end
      end)
    end)
  else
    -- Fallback to file-based formatting for older Neovim
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    M.format(bufnr, filepath, callback)
  end
end

return M
