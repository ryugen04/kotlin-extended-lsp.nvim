-- init.lua
-- kotlin-extended-lsp.nvim main entry point

local M = {}

-- Module state
M._initialized = false
M._attached_buffers = {}

-- Lazy load modules
local function load_module(name)
  return require('kotlin-extended-lsp.' .. name)
end

-- Setup function
function M.setup(user_config)
  if M._initialized then
    local logger = load_module('logger')
    logger.warn('kotlin-extended-lsp already initialized')
    return
  end

  -- Setup configuration first
  local config = load_module('config')
  config.setup(user_config)

  -- Setup logger
  local logger = load_module('logger')
  local log_config = config.get_value('log')
  logger.setup({
    level = logger.levels[log_config.level:upper()] or logger.levels.INFO,
    use_console = log_config.use_console,
    use_file = log_config.use_file,
    file_path = log_config.file_path,
  })

  logger.info('kotlin-extended-lsp.nvim initializing')

  -- Check if plugin is enabled
  if not config.get_value('enabled') then
    logger.info('Plugin disabled in configuration')
    return
  end

  -- Setup LspAttach autocmd
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('KotlinExtendedLsp', { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)

      -- Only attach to kotlin-lsp
      if not client or client.name ~= 'kotlin_lsp' then
        return
      end

      logger.debug('LspAttach event triggered', { client = client.name, buffer = args.buf })
      M.on_attach(client, args.buf)
    end,
  })

  -- Setup user commands
  M.setup_commands()

  -- Setup autocommands
  M.setup_autocommands()

  -- Initialize decompile cache
  local _ = load_module('decompile')
  if config.get_value('performance.cache_enabled') then
    logger.debug('Initializing decompile cache')
  end

  -- Register linters and formatters
  M.register_tools()

  M._initialized = true
  logger.info('kotlin-extended-lsp.nvim initialized successfully')
end

-- Register linters and formatters
function M.register_tools()
  local logger = load_module('logger')

  -- Register linters
  local linter = load_module('linter')
  local detekt = load_module('tools.detekt')
  local ktlint = load_module('tools.ktlint')

  linter.register('detekt', detekt)
  linter.register('ktlint', ktlint)
  logger.debug('Registered linters')

  -- Register formatters
  local formatter = load_module('formatter')
  local ktfmt = load_module('tools.ktfmt')

  formatter.register('ktlint', ktlint)
  formatter.register('ktfmt', ktfmt)
  logger.debug('Registered formatters')
end

-- On attach handler
function M.on_attach(client, bufnr)
  local logger = load_module('logger')
  local config = load_module('config')

  logger.info('Attaching to buffer', { buffer = bufnr, client = client.name })

  -- Mark buffer as attached
  M._attached_buffers[bufnr] = true

  -- Show capabilities report if configured
  if config.get_value('show_capabilities_on_attach') then
    local lsp_client = load_module('lsp_client')
    local report = lsp_client.get_capabilities_report()
    print(report)
  end

  -- Setup keymaps if configured
  if config.get_value('auto_setup_keymaps') then
    M.setup_keymaps(bufnr)
  end

  -- Register global handlers if configured
  if config.get_value('use_global_handlers') then
    local handlers = load_module('handlers')
    handlers.register_global_handlers()
  end

  -- Setup linting
  if config.get_value('linting.enabled') then
    local linter = load_module('linter')
    linter.setup_buffer(bufnr)
  end

  -- Setup formatting
  if config.get_value('formatting.enabled') then
    local formatter = load_module('formatter')
    formatter.setup_buffer(bufnr)
  end

  -- Setup editor settings
  local editor = load_module('editor')
  editor.setup_buffer(bufnr)

  logger.debug('Attachment complete', { buffer = bufnr })
end

-- Setup keymaps for buffer
function M.setup_keymaps(bufnr)
  local logger = load_module('logger')
  local config = load_module('config')
  local handlers = load_module('handlers')

  local keymaps = config.get_value('keymaps')
  local silent_fallbacks = config.get_value('silent_fallbacks')
  local opts = { buffer = bufnr, noremap = true, silent = true }

  logger.debug('Setting up keymaps', { buffer = bufnr, keymaps = keymaps })

  -- Navigation: Extended definition
  if keymaps.definition and keymaps.definition ~= '' then
    vim.keymap.set('n', keymaps.definition, function()
      handlers.extended_definition({ silent = silent_fallbacks })
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Go to definition' }))
  end

  -- Navigation: Extended implementation
  if keymaps.implementation and keymaps.implementation ~= '' then
    vim.keymap.set('n', keymaps.implementation, function()
      handlers.extended_implementation({ silent = silent_fallbacks })
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Go to implementation' }))
  end

  -- Navigation: Extended type definition
  if keymaps.type_definition and keymaps.type_definition ~= '' then
    vim.keymap.set('n', keymaps.type_definition, function()
      handlers.extended_type_definition({ silent = silent_fallbacks })
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Go to type definition' }))
  end

  -- Navigation: Extended declaration
  if keymaps.declaration and keymaps.declaration ~= '' then
    vim.keymap.set('n', keymaps.declaration, function()
      handlers.extended_declaration({ silent = silent_fallbacks })
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Go to declaration' }))
  end

  -- Navigation: References
  if keymaps.references and keymaps.references ~= '' then
    vim.keymap.set('n', keymaps.references, function()
      handlers.references()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Find references' }))
  end

  -- Documentation: Hover
  if keymaps.hover and keymaps.hover ~= '' then
    vim.keymap.set('n', keymaps.hover, function()
      handlers.hover()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Hover documentation' }))
  end

  -- Documentation: Signature help
  if keymaps.signature_help and keymaps.signature_help ~= '' then
    vim.keymap.set('n', keymaps.signature_help, function()
      handlers.signature_help()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Signature help' }))
    vim.keymap.set('i', keymaps.signature_help, function()
      handlers.signature_help()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Signature help' }))
  end

  -- Editing: Rename
  if keymaps.rename and keymaps.rename ~= '' then
    vim.keymap.set('n', keymaps.rename, function()
      handlers.rename()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Rename symbol' }))
  end

  -- Editing: Code action
  if keymaps.code_action and keymaps.code_action ~= '' then
    vim.keymap.set({ 'n', 'v' }, keymaps.code_action, function()
      handlers.code_action()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Code action' }))
  end

  -- Editing: Format
  if keymaps.format and keymaps.format ~= '' then
    vim.keymap.set('n', keymaps.format, function()
      handlers.format()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Format document' }))
    vim.keymap.set('v', keymaps.format, function()
      handlers.range_format()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Format range' }))
  end

  -- Diagnostics: Go to previous diagnostic
  if keymaps.goto_prev and keymaps.goto_prev ~= '' then
    vim.keymap.set('n', keymaps.goto_prev, function()
      handlers.goto_prev_diagnostic()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Previous diagnostic' }))
  end

  -- Diagnostics: Go to next diagnostic
  if keymaps.goto_next and keymaps.goto_next ~= '' then
    vim.keymap.set('n', keymaps.goto_next, function()
      handlers.goto_next_diagnostic()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Next diagnostic' }))
  end

  -- Diagnostics: Open float
  if keymaps.open_float and keymaps.open_float ~= '' then
    vim.keymap.set('n', keymaps.open_float, function()
      handlers.open_diagnostic_float()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Show diagnostic' }))
  end

  -- Diagnostics: Set loclist
  if keymaps.setloclist and keymaps.setloclist ~= '' then
    vim.keymap.set('n', keymaps.setloclist, function()
      handlers.set_diagnostic_loclist()
    end, vim.tbl_extend('force', opts, { desc = 'LSP: Diagnostics to loclist' }))
  end

  logger.info('Keymaps configured', { buffer = bufnr })
end

-- Setup user commands
function M.setup_commands()
  local logger = load_module('logger')

  -- Show capabilities
  vim.api.nvim_create_user_command('KotlinLspCapabilities', function()
    local lsp_client = load_module('lsp_client')
    local report = lsp_client.get_capabilities_report()
    print(report)
  end, { desc = 'Show kotlin-lsp server capabilities' })

  -- Decompile
  vim.api.nvim_create_user_command('KotlinDecompile', function(opts)
    local decompile = load_module('decompile')
    local uri = opts.args

    if uri == '' then
      uri = vim.uri_from_bufnr(0)
    end

    if not decompile.is_compiled_file(uri) then
      vim.notify(
        string.format('Not a compiled file: %s', uri),
        vim.log.levels.WARN,
        { title = 'kotlin-extended-lsp' }
      )
      return
    end

    decompile.decompile_uri(uri, function(err, content)
      if err then
        vim.notify(
          string.format('Decompile failed: %s', err),
          vim.log.levels.ERROR,
          { title = 'kotlin-extended-lsp' }
        )
        return
      end

      decompile.show_decompiled(uri, content, {})
    end)
  end, {
    desc = 'Decompile a JAR/class file',
    nargs = '?',
    complete = 'file',
  })

  -- Clear cache
  vim.api.nvim_create_user_command('KotlinClearCache', function()
    local decompile = load_module('decompile')
    decompile.clear_cache()
    vim.notify('Decompile cache cleared', vim.log.levels.INFO, { title = 'kotlin-extended-lsp' })
  end, { desc = 'Clear decompile cache' })

  -- Clean expired cache entries
  vim.api.nvim_create_user_command('KotlinCleanCache', function()
    local decompile = load_module('decompile')
    local removed = decompile.clean_cache()
    vim.notify(
      string.format('Cleaned %d expired cache entries', removed),
      vim.log.levels.INFO,
      { title = 'kotlin-extended-lsp' }
    )
  end, { desc = 'Clean expired cache entries' })

  -- Show cache statistics
  vim.api.nvim_create_user_command('KotlinCacheStats', function()
    local decompile = load_module('decompile')
    local stats = decompile.cache_stats()
    print(vim.inspect(stats))
  end, { desc = 'Show cache statistics' })

  -- Toggle logging
  vim.api.nvim_create_user_command('KotlinToggleLog', function(opts)
    local config = load_module('config')
    local level = opts.args

    if level == '' then
      local current = config.get_value('log.level')
      print('Current log level: ' .. current)
      return
    end

    config.update('log.level', level)
    logger.setup({ level = logger.levels[level:upper()] or logger.levels.INFO })

    vim.notify(
      string.format('Log level set to: %s', level),
      vim.log.levels.INFO,
      { title = 'kotlin-extended-lsp' }
    )
  end, {
    desc = 'Toggle logging level',
    nargs = '?',
    complete = function()
      return { 'trace', 'debug', 'info', 'warn', 'error', 'off' }
    end,
  })

  -- Show config
  vim.api.nvim_create_user_command('KotlinShowConfig', function()
    local config = load_module('config')
    print(vim.inspect(config.get()))
  end, { desc = 'Show current configuration' })

  -- Linting commands
  vim.api.nvim_create_user_command('KotlinLint', function()
    local linter = load_module('linter')
    linter.lint(vim.api.nvim_get_current_buf(), function(err, diagnostics)
      if err then
        vim.notify('Linting failed: ' .. err, vim.log.levels.ERROR, { title = 'kotlin-extended-lsp' })
      else
        vim.notify(
          string.format('Linting complete: %d issues found', #diagnostics),
          vim.log.levels.INFO,
          { title = 'kotlin-extended-lsp' }
        )
      end
    end)
  end, { desc = 'Lint current buffer' })

  vim.api.nvim_create_user_command('KotlinToggleLinting', function()
    local config = load_module('config')
    local current = config.get_value('linting.enabled')
    config.update('linting.enabled', not current)
    vim.notify(
      string.format('Linting %s', not current and 'enabled' or 'disabled'),
      vim.log.levels.INFO,
      { title = 'kotlin-extended-lsp' }
    )
  end, { desc = 'Toggle linting on/off' })

  -- Formatting commands
  vim.api.nvim_create_user_command('KotlinFormat', function(opts)
    local formatter = load_module('formatter')
    local tool = opts.args ~= '' and opts.args or nil
    formatter.format(vim.api.nvim_get_current_buf(), tool, function(err)
      if err then
        vim.notify('Formatting failed: ' .. err, vim.log.levels.ERROR, { title = 'kotlin-extended-lsp' })
      else
        vim.notify('Formatting complete', vim.log.levels.INFO, { title = 'kotlin-extended-lsp' })
      end
    end)
  end, {
    desc = 'Format current buffer',
    nargs = '?',
    complete = function()
      return { 'ktlint', 'ktfmt', 'lsp' }
    end,
  })

  -- Editor commands
  vim.api.nvim_create_user_command('KotlinOrganizeImports', function()
    local editor = load_module('editor')
    editor.organize_imports(vim.api.nvim_get_current_buf(), function(err)
      if err then
        vim.notify('Organize imports failed: ' .. err, vim.log.levels.ERROR, { title = 'kotlin-extended-lsp' })
      else
        vim.notify('Imports organized', vim.log.levels.INFO, { title = 'kotlin-extended-lsp' })
      end
    end)
  end, { desc = 'Organize imports' })

  logger.debug('User commands registered')
end

-- Setup autocommands
function M.setup_autocommands()
  local logger = load_module('logger')
  local group = vim.api.nvim_create_augroup('KotlinExtendedLspAuto', { clear = true })

  -- Cleanup on VimLeavePre
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      logger.close()
    end,
  })

  -- Cleanup attached buffers on BufDelete
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(args)
      if M._attached_buffers[args.buf] then
        M._attached_buffers[args.buf] = nil
        logger.debug('Removed buffer from attached list', { buffer = args.buf })
      end
    end,
  })

  logger.debug('Autocommands registered')
end

-- Get handlers (for programmatic use)
function M.get_handlers()
  return load_module('handlers')
end

-- Get LSP client utilities
function M.get_lsp_client()
  return load_module('lsp_client')
end

-- Get decompile utilities
function M.get_decompile()
  return load_module('decompile')
end

-- Get config
function M.get_config()
  return load_module('config')
end

-- Get logger
function M.get_logger()
  return load_module('logger')
end

-- Get linter
function M.get_linter()
  return load_module('linter')
end

-- Get formatter
function M.get_formatter()
  return load_module('formatter')
end

-- Get editor
function M.get_editor()
  return load_module('editor')
end

-- Health check
function M.check()
  local health = vim.health or require('health')
  local start = health.start or health.report_start
  local ok = health.ok or health.report_ok
  local warn = health.warn or health.report_warn
  local error = health.error or health.report_error

  start('kotlin-extended-lsp.nvim')

  -- Check if plugin is initialized
  if not M._initialized then
    warn('Plugin not initialized. Call require("kotlin-extended-lsp").setup()')
    return
  end
  ok('Plugin initialized')

  -- Check if kotlin-lsp is available
  local lsp_client = load_module('lsp_client')
  local client = lsp_client.get_kotlin_client()
  if not client then
    warn('kotlin-lsp not running. Start it by opening a Kotlin file.')
  else
    ok(string.format('kotlin-lsp connected (version: %s)', client.name))

    -- Check capabilities
    local caps = lsp_client.get_capabilities()
    if caps then
      ok('Server capabilities available')

      -- Navigation capabilities
      if caps.definitionProvider then
        ok('textDocument/definition supported')
      else
        error('textDocument/definition not supported')
      end

      if caps.implementationProvider then
        ok('textDocument/implementation supported')
      else
        warn('textDocument/implementation not supported (will fallback to definition)')
      end

      if caps.typeDefinitionProvider then
        ok('textDocument/typeDefinition supported')
      else
        warn('textDocument/typeDefinition not supported (will fallback to definition)')
      end

      if caps.declarationProvider then
        ok('textDocument/declaration supported')
      else
        warn('textDocument/declaration not supported (will fallback to definition)')
      end

      if caps.referencesProvider then
        ok('textDocument/references supported')
      else
        warn('textDocument/references not supported')
      end

      -- Documentation capabilities
      if caps.hoverProvider then
        ok('textDocument/hover supported')
      else
        warn('textDocument/hover not supported')
      end

      if caps.signatureHelpProvider then
        ok('textDocument/signatureHelp supported')
      else
        warn('textDocument/signatureHelp not supported')
      end

      -- Editing capabilities
      if caps.renameProvider then
        ok('textDocument/rename supported')
      else
        warn('textDocument/rename not supported')
      end

      if caps.codeActionProvider then
        ok('textDocument/codeAction supported')
      else
        warn('textDocument/codeAction not supported')
      end

      if caps.documentFormattingProvider then
        ok('textDocument/formatting supported')
      else
        warn('textDocument/formatting not supported')
      end

      if caps.documentRangeFormattingProvider then
        ok('textDocument/rangeFormatting supported')
      else
        warn('textDocument/rangeFormatting not supported')
      end

      -- Custom commands
      if lsp_client.supports_custom_command('kotlin/jarClassContents') then
        ok('kotlin/jarClassContents custom command available')
      else
        warn('kotlin/jarClassContents not available (decompile will not work)')
      end
    end
  end

  -- Check configuration
  local config = load_module('config')
  if config.get_value('decompile.cache_enabled') then
    ok('Decompile cache enabled')
  else
    warn('Decompile cache disabled (may impact performance)')
  end
end

return M
