-- tools/detekt.lua
-- detekt linter integration

local M = {}

local config = require('kotlin-extended-lsp.config')
local job = require('kotlin-extended-lsp.utils.job')
local logger = require('kotlin-extended-lsp.logger')

--- Find detekt executable
--- @return string|nil
local function find_detekt()
  local cfg = config.get_value('linting.tools.detekt')
  if cfg and cfg.cmd then
    return cfg.cmd
  end

  local project_root = job.get_project_root()
  if project_root then
    -- Try Gradle wrapper first
    local gradlew = project_root .. '/gradlew'
    if vim.fn.executable(gradlew) == 1 then
      return gradlew
    end
  end

  -- Try standalone detekt
  return job.find_executable('detekt')
end

--- Check if detekt is available
--- @return boolean
function M.is_available()
  return find_detekt() ~= nil
end

--- Parse detekt XML output
--- @param xml string XML output
--- @return table Diagnostics
local function parse_detekt_xml(xml)
  local diagnostics = {}

  -- Simple XML parsing for <error> tags
  -- Format: <error line="N" column="M" severity="..." message="..." source="RuleName" />
  for line_str, col_str, severity, message, source in
    xml:gmatch(
      '<error%s+line="(%d+)"%s+column="(%d+)"%s+severity="(%w+)"%s+message="([^"]+)"%s+source="([^"]+)"%s*/>'
    )
  do
    local line = tonumber(line_str) or 1
    local col = tonumber(col_str) or 0

    -- Map severity
    local diag_severity = vim.diagnostic.severity.WARN
    if severity == 'error' then
      diag_severity = vim.diagnostic.severity.ERROR
    elseif severity == 'warning' then
      diag_severity = vim.diagnostic.severity.WARN
    elseif severity == 'info' then
      diag_severity = vim.diagnostic.severity.INFO
    end

    table.insert(diagnostics, {
      lnum = line - 1, -- 0-indexed
      col = col - 1,
      severity = diag_severity,
      source = 'detekt',
      message = message,
      code = source,
    })
  end

  return diagnostics
end

--- Parse detekt plain output (fallback)
--- @param output string Plain text output
--- @param filepath string File path
--- @return table Diagnostics
local function parse_detekt_plain(output, filepath)
  local diagnostics = {}

  -- Format: filepath:line:col: severity: message [RuleName]
  for line_str, col_str, severity, message, rule in
    output:gmatch('([%d]+):([%d]+):%s*(%w+):%s*(.-)%s*%[([^%]]+)%]')
  do
    local line = tonumber(line_str) or 1
    local col = tonumber(col_str) or 0

    -- Map severity
    local diag_severity = vim.diagnostic.severity.WARN
    if severity:lower():match('error') then
      diag_severity = vim.diagnostic.severity.ERROR
    elseif severity:lower():match('warn') then
      diag_severity = vim.diagnostic.severity.WARN
    elseif severity:lower():match('info') then
      diag_severity = vim.diagnostic.severity.INFO
    end

    table.insert(diagnostics, {
      lnum = line - 1,
      col = col - 1,
      severity = diag_severity,
      source = 'detekt',
      message = message,
      code = rule,
    })
  end

  return diagnostics
end

--- Lint a file with detekt
--- @param bufnr number Buffer number
--- @param filepath string File path
--- @param callback function Callback (err, diagnostics)
function M.lint(bufnr, filepath, callback)
  local cmd = find_detekt()
  if not cmd then
    callback('detekt not found', {})
    return
  end

  local cfg = config.get_value('linting.tools.detekt')
  local project_root = job.get_project_root(bufnr)

  local args = {}
  local is_gradle = cmd:match('gradlew$') ~= nil

  if is_gradle then
    -- Use Gradle
    table.insert(args, 'detekt')
    if cfg.parallel then
      table.insert(args, '--parallel')
    end
  else
    -- Standalone detekt
    table.insert(args, '--input')
    table.insert(args, filepath)

    -- Config file
    if cfg.config_file then
      table.insert(args, '--config')
      table.insert(args, cfg.config_file)
    elseif project_root then
      local default_config = project_root .. '/detekt.yml'
      if vim.fn.filereadable(default_config) == 1 then
        table.insert(args, '--config')
        table.insert(args, default_config)
      end
    end

    -- Baseline
    if cfg.baseline_file then
      table.insert(args, '--baseline')
      table.insert(args, cfg.baseline_file)
    end

    -- Build upon default config
    if cfg.build_upon_default_config then
      table.insert(args, '--build-upon-default-config')
    end

    -- Report format (XML for easier parsing)
    table.insert(args, '--report')
    table.insert(args, 'xml:stdout')
  end

  logger.debug('Running detekt', { cmd = cmd, args = args })

  job.run(cmd, args, {
    cwd = project_root,
    timeout = 30000, -- 30 seconds
  }, function(err, stdout, stderr, code)
    if err then
      logger.warn('detekt execution failed', { error = err, stderr = stderr })
      callback(err, {})
      return
    end

    -- detekt returns non-zero if issues found
    if code ~= 0 and stdout == '' then
      callback('detekt failed: ' .. stderr, {})
      return
    end

    -- Parse output
    local diagnostics = {}
    if stdout:match('<checkstyle') then
      -- XML format
      diagnostics = parse_detekt_xml(stdout)
    else
      -- Plain format (fallback)
      diagnostics = parse_detekt_plain(stdout, filepath)
    end

    logger.debug('detekt completed', { diagnostics = #diagnostics })
    callback(nil, diagnostics)
  end)
end

return M
