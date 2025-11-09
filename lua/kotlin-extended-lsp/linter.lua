-- linter.lua
-- Linter integration manager

local M = {}

local config = require('kotlin-extended-lsp.config')
local logger = require('kotlin-extended-lsp.logger')
local job = require('kotlin-extended-lsp.utils.job')

-- Registered linters
M._linters = {}

-- Diagnostic namespace
M._namespace = vim.api.nvim_create_namespace('kotlin_extended_lsp_linter')

-- Debounced lint functions per buffer
M._debounced_lint = {}

--- Register a linter
--- @param name string Linter name
--- @param linter table Linter implementation
function M.register(name, linter)
  if not linter.lint then
    error(string.format('Linter %s must implement lint() function', name))
  end

  M._linters[name] = linter
  logger.debug('Registered linter', { name = name })
end

--- Get a registered linter
--- @param name string Linter name
--- @return table|nil Linter implementation or nil
function M.get_linter(name)
  return M._linters[name]
end

--- Check if a linter is available
--- @param name string Linter name
--- @return boolean
function M.is_available(name)
  local linter = M._linters[name]
  if not linter then
    return false
  end

  if linter.is_available then
    return linter.is_available()
  end

  return true
end

--- Run all enabled linters on a buffer
--- @param bufnr number Buffer number
--- @param callback function|nil Callback (err, diagnostics)
function M.lint(bufnr, callback)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  callback = callback or function() end

  local cfg = config.get_value('linting')
  if not cfg or not cfg.enabled then
    logger.debug('Linting disabled')
    callback(nil, {})
    return
  end

  -- Check if buffer is a Kotlin file
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  if filetype ~= 'kotlin' then
    callback(nil, {})
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' or vim.fn.filereadable(filepath) == 0 then
    callback(nil, {})
    return
  end

  logger.debug('Running linters', { buffer = bufnr, filepath = filepath })

  local all_diagnostics = {}
  local pending = 0
  local has_error = false

  -- Run each enabled linter
  for name, tool_cfg in pairs(cfg.tools) do
    if tool_cfg.enabled then
      local linter = M._linters[name]
      if linter and M.is_available(name) then
        pending = pending + 1

        linter.lint(bufnr, filepath, function(err, diagnostics)
          pending = pending - 1

          if err then
            logger.warn('Linter failed', { linter = name, error = err })
            has_error = true
          elseif diagnostics then
            -- Add source to each diagnostic
            for _, diag in ipairs(diagnostics) do
              diag.source = diag.source or name
              table.insert(all_diagnostics, diag)
            end
            logger.debug('Linter completed', { linter = name, count = #diagnostics })
          end

          -- All linters completed
          if pending == 0 then
            -- Set diagnostics
            M.set_diagnostics(bufnr, all_diagnostics)

            if has_error then
              callback('One or more linters failed', all_diagnostics)
            else
              callback(nil, all_diagnostics)
            end
          end
        end)
      else
        logger.debug('Linter not available', { linter = name })
      end
    end
  end

  -- No linters ran
  if pending == 0 then
    callback(nil, {})
  end
end

--- Run linters with debounce
--- @param bufnr number Buffer number
function M.lint_debounced(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not M._debounced_lint[bufnr] then
    local cfg = config.get_value('linting')
    local debounce_ms = cfg and cfg.debounce_ms or 500

    M._debounced_lint[bufnr] = job.debounce(function()
      M.lint(bufnr)
    end, debounce_ms)
  end

  M._debounced_lint[bufnr]()
end

--- Set diagnostics for a buffer
--- @param bufnr number Buffer number
--- @param diagnostics table List of diagnostics
function M.set_diagnostics(bufnr, diagnostics)
  vim.diagnostic.set(M._namespace, bufnr, diagnostics, {})
  logger.debug('Set diagnostics', { buffer = bufnr, count = #diagnostics })
end

--- Clear diagnostics for a buffer
--- @param bufnr number Buffer number
function M.clear_diagnostics(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.diagnostic.reset(M._namespace, bufnr)
  logger.debug('Cleared diagnostics', { buffer = bufnr })
end

--- Setup linting for a buffer
--- @param bufnr number Buffer number
function M.setup_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cfg = config.get_value('linting')
  if not cfg or not cfg.enabled then
    return
  end

  local group = vim.api.nvim_create_augroup('KotlinExtendedLspLinter_' .. bufnr, { clear = true })

  -- Lint on save
  if cfg.on_save then
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = group,
      buffer = bufnr,
      callback = function()
        M.lint(bufnr)
      end,
    })
  end

  -- Lint on type (debounced)
  if cfg.on_type then
    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
      group = group,
      buffer = bufnr,
      callback = function()
        M.lint_debounced(bufnr)
      end,
    })
  end

  -- Initial lint
  M.lint(bufnr)

  logger.debug('Linter buffer setup complete', { buffer = bufnr })
end

--- Teardown linting for a buffer
--- @param bufnr number Buffer number
function M.teardown_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  M.clear_diagnostics(bufnr)
  M._debounced_lint[bufnr] = nil

  local ok = pcall(vim.api.nvim_del_augroup_by_name, 'KotlinExtendedLspLinter_' .. bufnr)
  if ok then
    logger.debug('Linter buffer teardown complete', { buffer = bufnr })
  end
end

--- Get linter status
--- @return table Status information
function M.status()
  local cfg = config.get_value('linting')
  local status = {
    enabled = cfg and cfg.enabled or false,
    linters = {},
  }

  if cfg then
    for name, tool_cfg in pairs(cfg.tools) do
      status.linters[name] = {
        enabled = tool_cfg.enabled,
        available = M.is_available(name),
      }
    end
  end

  return status
end

return M
