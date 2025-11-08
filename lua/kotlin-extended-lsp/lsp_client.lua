-- lsp_client.lua
-- Robust LSP client utilities with retry logic and error handling

local logger = require('kotlin-extended-lsp.logger')
local config = require('kotlin-extended-lsp.config')

local M = {}

-- Get kotlin-lsp client
function M.get_kotlin_client()
  local clients = vim.lsp.get_clients({ name = 'kotlin_lsp' })
  if #clients > 0 then
    return clients[1]
  end
  return nil
end

-- Check if kotlin-lsp is attached to buffer
function M.is_attached(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local client = M.get_kotlin_client()
  if not client then
    return false
  end

  local attached_buffers = vim.lsp.get_buffers_by_client_id(client.id)
  for _, buf in ipairs(attached_buffers) do
    if buf == bufnr then
      return true
    end
  end

  return false
end

-- Check if LSP method is supported
function M.supports_method(method)
  local client = M.get_kotlin_client()
  if not client then
    logger.warn(string.format('kotlin-lsp not found, cannot check method: %s', method))
    return false
  end

  local supported = client.supports_method(method)
  logger.debug(string.format('Method %s support: %s', method, supported))
  return supported
end

-- Make LSP request with retry logic
function M.request(method, params, handler, opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or config.get_value('lsp.timeout_ms')
  local retry_count = opts.retry_count or config.get_value('lsp.retry_count')
  local retry_delay_ms = opts.retry_delay_ms or config.get_value('lsp.retry_delay_ms')
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  local client = M.get_kotlin_client()
  if not client then
    local err_msg = 'kotlin-lsp client not found'
    logger.error(err_msg)
    if handler then
      handler(err_msg, nil)
    end
    return
  end

  logger.lsp_request(method, params)

  local function make_request(attempt)
    local request_success, request_id = pcall(function()
      return client.request(method, params, function(err, result, ctx, lsp_config)
        if err then
          logger.lsp_response(method, false, err)

          -- Retry logic
          if attempt < retry_count then
            logger.warn(string.format(
              'LSP request %s failed (attempt %d/%d), retrying in %dms',
              method,
              attempt,
              retry_count,
              retry_delay_ms
            ))

            vim.defer_fn(function()
              make_request(attempt + 1)
            end, retry_delay_ms)
            return
          end

          -- Final failure
          logger.error(string.format('LSP request %s failed after %d attempts', method, retry_count))
          if handler then
            handler(err, nil)
          end
          return
        end

        logger.lsp_response(method, true, result)
        if handler then
          handler(nil, result, ctx, lsp_config)
        end
      end, bufnr)
    end)

    if not request_success then
      logger.error(string.format('Failed to make LSP request: %s', request_id))
      if handler then
        handler(request_id, nil)
      end
      return
    end

    -- Setup timeout
    if timeout_ms > 0 then
      vim.defer_fn(function()
        if request_id then
          pcall(client.cancel_request, request_id)
          logger.warn(string.format('LSP request %s timed out after %dms', method, timeout_ms))
        end
      end, timeout_ms)
    end
  end

  make_request(1)
end

-- Make synchronous LSP request (blocks until response)
function M.request_sync(method, params, opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or config.get_value('lsp.timeout_ms')

  local result_data = nil
  local error_data = nil
  local completed = false

  M.request(method, params, function(err, result)
    error_data = err
    result_data = result
    completed = true
  end, opts)

  -- Wait for completion with timeout
  local start_time = vim.loop.now()
  while not completed do
    if vim.loop.now() - start_time > timeout_ms then
      logger.error(string.format('Synchronous LSP request %s timed out', method))
      return nil, 'timeout'
    end
    vim.wait(10)
  end

  return result_data, error_data
end

-- Check server capabilities
function M.get_capabilities()
  local client = M.get_kotlin_client()
  if not client then
    return nil
  end

  return client.server_capabilities
end

-- Get formatted capabilities report
function M.get_capabilities_report()
  local caps = M.get_capabilities()
  if not caps then
    return 'kotlin-lsp client not found'
  end

  local report = {
    '=== kotlin-lsp Server Capabilities ===',
    '',
    'Navigation:',
    string.format('  definitionProvider: %s', caps.definitionProvider and 'YES' or 'NO'),
    string.format('  declarationProvider: %s', caps.declarationProvider and 'YES' or 'NO'),
    string.format('  typeDefinitionProvider: %s', caps.typeDefinitionProvider and 'YES' or 'NO'),
    string.format('  implementationProvider: %s', caps.implementationProvider and 'YES' or 'NO'),
    string.format('  referencesProvider: %s', caps.referencesProvider and 'YES' or 'NO'),
    '',
    'Editing:',
    string.format('  renameProvider: %s', caps.renameProvider and 'YES' or 'NO'),
    string.format('  documentFormattingProvider: %s', caps.documentFormattingProvider and 'YES' or 'NO'),
    string.format('  codeActionProvider: %s', caps.codeActionProvider and 'YES' or 'NO'),
    '',
    'Information:',
    string.format('  hoverProvider: %s', caps.hoverProvider and 'YES' or 'NO'),
    string.format('  completionProvider: %s', caps.completionProvider and 'YES' or 'NO'),
    string.format('  signatureHelpProvider: %s', caps.signatureHelpProvider and 'YES' or 'NO'),
    '',
  }

  return table.concat(report, '\n')
end

-- Custom command support check
function M.supports_custom_command(command)
  -- kotlin-lsp specific custom commands
  local custom_commands = {
    'kotlin/jarClassContents',
    'kotlin/buildOutputLocation',
    'kotlin/mainClass',
  }

  for _, cmd in ipairs(custom_commands) do
    if cmd == command then
      return true
    end
  end

  return false
end

-- Execute custom kotlin-lsp command
function M.execute_command(command, args, handler, opts)
  if not M.supports_custom_command(command) then
    local err_msg = string.format('Custom command not supported: %s', command)
    logger.error(err_msg)
    if handler then
      handler(err_msg, nil)
    end
    return
  end

  M.request(command, args, handler, opts)
end

return M
