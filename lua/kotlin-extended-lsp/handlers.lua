-- handlers.lua
-- Enhanced LSP handlers with fallback strategies

local config = require('kotlin-extended-lsp.config')
local decompile = require('kotlin-extended-lsp.decompile')
local logger = require('kotlin-extended-lsp.logger')
local lsp_client = require('kotlin-extended-lsp.lsp_client')

local M = {}

-- Extended textDocument/definition
function M.extended_definition(opts)
  opts = opts or {}

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  local params = vim.lsp.util.make_position_params()

  lsp_client.request('textDocument/definition', params, function(err, result, ctx, lsp_config)
    decompile.handle_definition_result(err, result, ctx, lsp_config, opts)
  end)
end

-- Extended textDocument/implementation with fallback
function M.extended_implementation(opts)
  opts = opts or {}

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  local params = vim.lsp.util.make_position_params()

  -- Check if implementation is supported
  if not lsp_client.supports_method('textDocument/implementation') then
    logger.debug('textDocument/implementation not supported, falling back to definition')

    local silent_fallbacks = config.get_value('silent_fallbacks')
    if not silent_fallbacks and not opts.silent then
      vim.notify(
        'Implementation not supported, falling back to definition',
        vim.log.levels.INFO,
        { title = 'kotlin-extended-lsp' }
      )
    end

    M.extended_definition({ silent = true })
    return
  end

  lsp_client.request('textDocument/implementation', params, function(err, result, ctx, lsp_config)
    -- Check if we got results
    if not result or vim.tbl_isempty(result) or err then
      logger.debug('No implementation found or error, falling back to definition')

      local silent_fallbacks = config.get_value('silent_fallbacks')
      if not silent_fallbacks and not opts.silent then
        vim.notify(
          'Implementation not found, falling back to definition',
          vim.log.levels.INFO,
          { title = 'kotlin-extended-lsp' }
        )
      end

      M.extended_definition({ silent = true })
      return
    end

    -- Handle result with decompile support
    decompile.handle_definition_result(err, result, ctx, lsp_config, opts)
  end)
end

-- Extended textDocument/typeDefinition with fallback
function M.extended_type_definition(opts)
  opts = opts or {}

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  local params = vim.lsp.util.make_position_params()

  -- Check if type definition is supported
  if not lsp_client.supports_method('textDocument/typeDefinition') then
    logger.debug('textDocument/typeDefinition not supported, falling back to definition')

    local silent_fallbacks = config.get_value('silent_fallbacks')
    if not silent_fallbacks and not opts.silent then
      vim.notify(
        'Type definition not supported, falling back to definition',
        vim.log.levels.INFO,
        { title = 'kotlin-extended-lsp' }
      )
    end

    M.extended_definition({ silent = true })
    return
  end

  lsp_client.request('textDocument/typeDefinition', params, function(err, result, ctx, lsp_config)
    if not result or vim.tbl_isempty(result) or err then
      logger.debug('No type definition found or error, falling back to definition')

      local silent_fallbacks = config.get_value('silent_fallbacks')
      if not silent_fallbacks and not opts.silent then
        vim.notify(
          'Type definition not found, falling back to definition',
          vim.log.levels.INFO,
          { title = 'kotlin-extended-lsp' }
        )
      end

      M.extended_definition({ silent = true })
      return
    end

    decompile.handle_definition_result(err, result, ctx, lsp_config, opts)
  end)
end

-- Extended textDocument/declaration with fallback
function M.extended_declaration(opts)
  opts = opts or {}

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  local params = vim.lsp.util.make_position_params()

  -- Check if declaration is supported
  if not lsp_client.supports_method('textDocument/declaration') then
    logger.debug('textDocument/declaration not supported, falling back to definition')

    local silent_fallbacks = config.get_value('silent_fallbacks')
    if not silent_fallbacks and not opts.silent then
      vim.notify(
        'Declaration not supported, falling back to definition',
        vim.log.levels.INFO,
        { title = 'kotlin-extended-lsp' }
      )
    end

    M.extended_definition({ silent = true })
    return
  end

  lsp_client.request('textDocument/declaration', params, function(err, result, ctx, lsp_config)
    if not result or vim.tbl_isempty(result) or err then
      logger.debug('No declaration found or error, falling back to definition')

      local silent_fallbacks = config.get_value('silent_fallbacks')
      if not silent_fallbacks and not opts.silent then
        vim.notify(
          'Declaration not found, falling back to definition',
          vim.log.levels.INFO,
          { title = 'kotlin-extended-lsp' }
        )
      end

      M.extended_definition({ silent = true })
      return
    end

    decompile.handle_definition_result(err, result, ctx, lsp_config, opts)
  end)
end

-- Register global handlers (optional, use with caution)
function M.register_global_handlers()
  logger.warn('Registering global LSP handlers - this may affect other language servers')

  vim.lsp.handlers['textDocument/definition'] = function(err, result, ctx, lsp_config)
    decompile.handle_definition_result(err, result, ctx, lsp_config, {})
  end

  logger.info('Global handlers registered')
end

-- Unregister global handlers
function M.unregister_global_handlers()
  vim.lsp.handlers['textDocument/definition'] = nil
  logger.info('Global handlers unregistered')
end

-- textDocument/references (参照検索)
function M.references(opts)
  opts = opts or {}

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  if not lsp_client.supports_method('textDocument/references') then
    logger.warn('textDocument/references not supported')
    vim.notify(
      'References not supported by kotlin-lsp',
      vim.log.levels.WARN,
      { title = 'kotlin-extended-lsp' }
    )
    return
  end

  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = opts.include_declaration ~= false }

  vim.lsp.buf.references(params.context, opts)
end

-- textDocument/hover (ホバードキュメント)
function M.hover(_opts)

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  if not lsp_client.supports_method('textDocument/hover') then
    logger.warn('textDocument/hover not supported')
    vim.notify(
      'Hover not supported by kotlin-lsp',
      vim.log.levels.WARN,
      { title = 'kotlin-extended-lsp' }
    )
    return
  end

  vim.lsp.buf.hover()
end

-- textDocument/signatureHelp (シグネチャヘルプ)
function M.signature_help(_opts)

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  if not lsp_client.supports_method('textDocument/signatureHelp') then
    logger.warn('textDocument/signatureHelp not supported')
    return
  end

  vim.lsp.buf.signature_help()
end

-- textDocument/rename (シンボルリネーム)
function M.rename(opts)
  opts = opts or {}

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  if not lsp_client.supports_method('textDocument/rename') then
    logger.warn('textDocument/rename not supported')
    vim.notify(
      'Rename not supported by kotlin-lsp',
      vim.log.levels.WARN,
      { title = 'kotlin-extended-lsp' }
    )
    return
  end

  local new_name = opts.new_name
  if not new_name then
    new_name = vim.fn.input('New name: ', vim.fn.expand('<cword>'))
  end

  if new_name and new_name ~= '' then
    vim.lsp.buf.rename(new_name)
  end
end

-- textDocument/codeAction (コードアクション)
function M.code_action(opts)
  opts = opts or {}

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  if not lsp_client.supports_method('textDocument/codeAction') then
    logger.warn('textDocument/codeAction not supported')
    vim.notify(
      'Code actions not supported by kotlin-lsp',
      vim.log.levels.WARN,
      { title = 'kotlin-extended-lsp' }
    )
    return
  end

  vim.lsp.buf.code_action(opts)
end

-- textDocument/formatting (ドキュメントフォーマット)
function M.format(opts)
  opts = opts or {}

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  if not lsp_client.supports_method('textDocument/formatting') then
    logger.debug('textDocument/formatting not supported')

    if not opts.silent then
      vim.notify(
        'Formatting not supported by kotlin-lsp',
        vim.log.levels.INFO,
        { title = 'kotlin-extended-lsp' }
      )
    end
    return
  end

  vim.lsp.buf.format({
    async = opts.async ~= false,
    timeout_ms = opts.timeout_ms or config.get_value('lsp.timeout_ms'),
  })
end

-- textDocument/rangeFormatting (範囲フォーマット)
function M.range_format(opts)
  opts = opts or {}

  if not lsp_client.is_attached() then
    logger.error('kotlin-lsp not attached to current buffer')
    return
  end

  if not lsp_client.supports_method('textDocument/rangeFormatting') then
    logger.debug('textDocument/rangeFormatting not supported, trying full document format')
    M.format(opts)
    return
  end

  vim.lsp.buf.format({
    async = opts.async ~= false,
    timeout_ms = opts.timeout_ms or config.get_value('lsp.timeout_ms'),
  })
end

-- vim.diagnostic wrapper functions
function M.goto_prev_diagnostic(opts)
  opts = opts or {}
  vim.diagnostic.goto_prev(opts)
end

function M.goto_next_diagnostic(opts)
  opts = opts or {}
  vim.diagnostic.goto_next(opts)
end

function M.open_diagnostic_float(opts)
  opts = opts or {}
  vim.diagnostic.open_float(opts)
end

function M.set_diagnostic_loclist(opts)
  opts = opts or {}
  vim.diagnostic.setloclist(opts)
end

function M.set_diagnostic_qflist(opts)
  opts = opts or {}
  vim.diagnostic.setqflist(opts)
end

return M
