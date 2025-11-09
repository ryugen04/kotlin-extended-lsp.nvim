-- tools/ktlint.lua
-- ktlint linter and formatter integration

local M = {}

local config = require('kotlin-extended-lsp.config')
local logger = require('kotlin-extended-lsp.logger')
local job = require('kotlin-extended-lsp.utils.job')

--- Find ktlint executable
--- @param mode string 'lint' or 'format'
--- @return string|nil
local function find_ktlint(mode)
  local cfg_key = mode == 'format' and 'formatting.tools.ktlint' or 'linting.tools.ktlint'
  local cfg = config.get_value(cfg_key)
  if cfg and cfg.cmd then
    return cfg.cmd
  end

  local project_root = job.get_project_root()
  if project_root then
    -- Try Gradle wrapper
    local gradlew = project_root .. '/gradlew'
    if vim.fn.executable(gradlew) == 1 then
      return gradlew
    end
  end

  -- Try standalone ktlint
  return job.find_executable('ktlint')
end

--- Check if ktlint is available
--- @param mode string 'lint' or 'format'
--- @return boolean
function M.is_available(mode)
  return find_ktlint(mode or 'lint') ~= nil
end

--- Parse ktlint output
--- @param output string ktlint output
--- @param filepath string File path
--- @return table Diagnostics
local function parse_ktlint_output(output, filepath)
  local diagnostics = {}

  -- Format: filepath:line:col: message (rule-name)
  -- Example: /path/to/file.kt:10:5: Unnecessary semicolon (no-semi)
  for line in output:gmatch('[^\r\n]+') do
    local file, line_str, col_str, message = line:match('^([^:]+):(%d+):(%d+):%s*(.+)$')

    if file and line_str and col_str and message then
      local line_num = tonumber(line_str) or 1
      local col_num = tonumber(col_str) or 0

      -- Extract rule name
      local rule = message:match('%(([^)]+)%)$')
      if rule then
        message = message:gsub('%s*%(' .. rule .. '%)$', '')
      end

      table.insert(diagnostics, {
        lnum = line_num - 1, -- 0-indexed
        col = col_num - 1,
        severity = vim.diagnostic.severity.WARN,
        source = 'ktlint',
        message = message,
        code = rule or 'ktlint',
      })
    end
  end

  return diagnostics
end

--- Lint a file with ktlint
--- @param bufnr number Buffer number
--- @param filepath string File path
--- @param callback function Callback (err, diagnostics)
function M.lint(bufnr, filepath, callback)
  local cmd = find_ktlint('lint')
  if not cmd then
    callback('ktlint not found', {})
    return
  end

  local cfg = config.get_value('linting.tools.ktlint')
  local project_root = job.get_project_root(bufnr)

  local args = {}
  local is_gradle = cmd:match('gradlew$') ~= nil

  if is_gradle then
    -- Use Gradle
    table.insert(args, 'ktlintCheck')
  else
    -- Standalone ktlint
    -- Config file (.editorconfig)
    if cfg.config_file then
      table.insert(args, '--editorconfig=' .. cfg.config_file)
    end

    -- Android style
    if cfg.android then
      table.insert(args, '--android')
    end

    -- Experimental rules
    if cfg.experimental then
      table.insert(args, '--experimental')
    end

    -- File to lint
    table.insert(args, filepath)
  end

  logger.debug('Running ktlint', { cmd = cmd, args = args })

  job.run(cmd, args, {
    cwd = project_root,
    timeout = 15000, -- 15 seconds
  }, function(err, stdout, stderr, code)
    -- ktlint returns non-zero if issues found
    if code ~= 0 and stdout == '' and stderr ~= '' then
      logger.warn('ktlint execution failed', { error = stderr })
      callback(stderr, {})
      return
    end

    -- Parse output (errors go to stdout for ktlint)
    local output = stdout ~= '' and stdout or stderr
    local diagnostics = parse_ktlint_output(output, filepath)

    logger.debug('ktlint lint completed', { diagnostics = #diagnostics })
    callback(nil, diagnostics)
  end)
end

--- Format a file with ktlint
--- @param bufnr number Buffer number
--- @param filepath string File path
--- @param callback function Callback (err, formatted_content)
function M.format(bufnr, filepath, callback)
  local cmd = find_ktlint('format')
  if not cmd then
    callback('ktlint not found', nil)
    return
  end

  local cfg = config.get_value('formatting.tools.ktlint')
  local project_root = job.get_project_root(bufnr)

  local args = {}
  local is_gradle = cmd:match('gradlew$') ~= nil

  if is_gradle then
    -- Use Gradle
    table.insert(args, 'ktlintFormat')
  else
    -- Standalone ktlint
    table.insert(args, '--format')

    -- Config file
    if cfg.config_file then
      table.insert(args, '--editorconfig=' .. cfg.config_file)
    end

    -- Android style
    if cfg.android then
      table.insert(args, '--android')
    end

    -- File to format
    table.insert(args, filepath)
  end

  logger.debug('Running ktlint format', { cmd = cmd, args = args })

  job.run(cmd, args, {
    cwd = project_root,
    timeout = 15000,
  }, function(err, stdout, stderr, code)
    if err then
      logger.warn('ktlint format failed', { error = err, stderr = stderr })
      callback(err, nil)
      return
    end

    -- ktlint formats in-place, so we need to read the file
    local formatted_content = vim.fn.readfile(filepath)

    logger.debug('ktlint format completed')
    callback(nil, formatted_content)
  end)
end

--- Format buffer content (without writing to file)
--- @param bufnr number Buffer number
--- @param content table Buffer lines
--- @param callback function Callback (err, formatted_lines)
function M.format_buffer(bufnr, content, callback)
  local cmd = find_ktlint('format')
  if not cmd then
    callback('ktlint not found', nil)
    return
  end

  local cfg = config.get_value('formatting.tools.ktlint')
  local is_gradle = cmd:match('gradlew$') ~= nil

  if is_gradle then
    -- Gradle doesn't support stdin, fallback to file-based formatting
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    M.format(bufnr, filepath, callback)
    return
  end

  local args = {}
  table.insert(args, '--format')
  table.insert(args, '--stdin')

  if cfg.config_file then
    table.insert(args, '--editorconfig=' .. cfg.config_file)
  end

  if cfg.android then
    table.insert(args, '--android')
  end

  logger.debug('Running ktlint format on buffer', { cmd = cmd, args = args })

  -- Create temporary input
  local input = table.concat(content, '\n')

  -- Use vim.system for stdin support (Neovim 0.10+)
  if vim.system then
    vim.system({ cmd, unpack(args) }, {
      stdin = input,
      text = true,
    }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          callback(result.stderr or 'ktlint failed', nil)
        else
          local lines = vim.split(result.stdout, '\n', { plain = true })
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
