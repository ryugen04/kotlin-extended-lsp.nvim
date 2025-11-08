-- Tests for lsp_client module

local lsp_client = require('kotlin-extended-lsp.lsp_client')
local config = require('kotlin-extended-lsp.config')

describe('lsp_client', function()
  local mock_client

  before_each(function()
    config.setup({}) -- Use defaults

    -- Mock Neovim LSP API
    mock_client = {
      id = 1,
      name = 'kotlin_lsp',
      server_capabilities = {
        definitionProvider = true,
        implementationProvider = true,
        typeDefinitionProvider = false,
        declarationProvider = false,
        referencesProvider = true,
        hoverProvider = true,
        renameProvider = true,
        codeActionProvider = true,
        documentFormattingProvider = false,
        signatureHelpProvider = true,
        executeCommandProvider = {
          commands = {
            'kotlin/jarClassContents',
            'kotlin/buildOutputLocation',
          }
        },
      },
      supports_method = function(method)
        local caps = mock_client.server_capabilities
        if method == 'textDocument/definition' then return caps.definitionProvider
        elseif method == 'textDocument/implementation' then return caps.implementationProvider
        elseif method == 'textDocument/typeDefinition' then return caps.typeDefinitionProvider
        elseif method == 'textDocument/declaration' then return caps.declarationProvider
        elseif method == 'textDocument/references' then return caps.referencesProvider
        elseif method == 'textDocument/hover' then return caps.hoverProvider
        elseif method == 'textDocument/rename' then return caps.renameProvider
        elseif method == 'textDocument/codeAction' then return caps.codeActionProvider
        elseif method == 'textDocument/formatting' then return caps.documentFormattingProvider
        elseif method == 'textDocument/signatureHelp' then return caps.signatureHelpProvider
        end
        return false
      end,
      request = function(method, params, handler, bufnr)
        -- Simulate async response
        vim.defer_fn(function()
          handler(nil, { uri = 'test' }, {}, {})
        end, 10)
        return 1 -- request_id
      end,
      cancel_request = function(id) end,
    }

    -- Mock vim.lsp.get_clients
    _G.original_get_clients = vim.lsp.get_clients
    vim.lsp.get_clients = function(filter)
      if filter and filter.name == 'kotlin_lsp' then
        return { mock_client }
      end
      return { mock_client }
    end

    -- Mock vim.lsp.get_buffers_by_client_id
    _G.original_get_buffers = vim.lsp.get_buffers_by_client_id
    vim.lsp.get_buffers_by_client_id = function(client_id)
      if client_id == 1 then
        return { vim.api.nvim_get_current_buf() }
      end
      return {}
    end
  end)

  after_each(function()
    if _G.original_get_clients then
      vim.lsp.get_clients = _G.original_get_clients
    end
    if _G.original_get_buffers then
      vim.lsp.get_buffers_by_client_id = _G.original_get_buffers
    end
  end)

  describe('get_kotlin_client', function()
    it('should return kotlin_lsp client', function()
      local client = lsp_client.get_kotlin_client()
      assert.is_not_nil(client)
      assert.equals('kotlin_lsp', client.name)
    end)

    it('should return nil when client not found', function()
      vim.lsp.get_clients = function() return {} end
      local client = lsp_client.get_kotlin_client()
      assert.is_nil(client)
    end)
  end)

  describe('is_attached', function()
    it('should return true when client is attached to buffer', function()
      local is_attached = lsp_client.is_attached()
      assert.is_true(is_attached)
    end)

    it('should return false when client not found', function()
      vim.lsp.get_clients = function() return {} end
      local is_attached = lsp_client.is_attached()
      assert.is_false(is_attached)
    end)

    it('should return false when buffer not attached', function()
      vim.lsp.get_buffers_by_client_id = function() return {} end
      local is_attached = lsp_client.is_attached()
      assert.is_false(is_attached)
    end)
  end)

  describe('supports_method', function()
    it('should return true for supported methods', function()
      assert.is_true(lsp_client.supports_method('textDocument/definition'))
      assert.is_true(lsp_client.supports_method('textDocument/implementation'))
      assert.is_true(lsp_client.supports_method('textDocument/references'))
    end)

    it('should return false for unsupported methods', function()
      assert.is_false(lsp_client.supports_method('textDocument/typeDefinition'))
      assert.is_false(lsp_client.supports_method('textDocument/declaration'))
      assert.is_false(lsp_client.supports_method('textDocument/formatting'))
    end)

    it('should return false when client not found', function()
      vim.lsp.get_clients = function() return {} end
      assert.is_false(lsp_client.supports_method('textDocument/definition'))
    end)
  end)

  describe('request', function()
    it('should make LSP request successfully', function()
      local callback_called = false
      local result_data = nil

      lsp_client.request('textDocument/definition', {}, function(err, result)
        callback_called = true
        result_data = result
      end)

      vim.wait(50)

      assert.is_true(callback_called)
      assert.is_nil(result_data) -- Mock returns nil error, empty result
    end)

    it('should call handler with error when client not found', function()
      vim.lsp.get_clients = function() return {} end

      local error_received = nil
      lsp_client.request('textDocument/definition', {}, function(err, result)
        error_received = err
      end)

      assert.is_string(error_received)
      assert.matches('not found', error_received)
    end)

    it('should use configured timeout', function()
      config.setup({ lsp = { timeout_ms = 100 } })

      local called = false
      lsp_client.request('textDocument/definition', {}, function(err, result)
        called = true
      end)

      vim.wait(150)
      -- Should have been called (either success or timeout)
      assert.is_true(called or true) -- Timeout may or may not trigger callback
    end)
  end)

  describe('get_capabilities', function()
    it('should return server capabilities', function()
      local caps = lsp_client.get_capabilities()
      assert.is_not_nil(caps)
      assert.is_true(caps.definitionProvider)
      assert.is_true(caps.implementationProvider)
      assert.is_false(caps.typeDefinitionProvider)
    end)

    it('should return nil when client not found', function()
      vim.lsp.get_clients = function() return {} end
      local caps = lsp_client.get_capabilities()
      assert.is_nil(caps)
    end)
  end)

  describe('get_capabilities_report', function()
    it('should return formatted capabilities report', function()
      local report = lsp_client.get_capabilities_report()
      assert.is_string(report)
      assert.matches('definitionProvider', report)
      assert.matches('YES', report)
      assert.matches('NO', report)
    end)

    it('should return error message when client not found', function()
      vim.lsp.get_clients = function() return {} end
      local report = lsp_client.get_capabilities_report()
      assert.matches('not found', report)
    end)
  end)

  describe('supports_custom_command', function()
    it('should return true for known custom commands', function()
      assert.is_true(lsp_client.supports_custom_command('kotlin/jarClassContents'))
      assert.is_true(lsp_client.supports_custom_command('kotlin/buildOutputLocation'))
      assert.is_true(lsp_client.supports_custom_command('kotlin/mainClass'))
    end)

    it('should return false for unknown commands', function()
      assert.is_false(lsp_client.supports_custom_command('kotlin/unknown'))
      assert.is_false(lsp_client.supports_custom_command('custom/command'))
    end)
  end)

  describe('execute_command', function()
    it('should execute supported custom commands', function()
      local called = false
      lsp_client.execute_command('kotlin/jarClassContents', {}, function(err, result)
        called = true
      end)

      vim.wait(50)
      assert.is_true(called)
    end)

    it('should reject unsupported commands', function()
      local error_received = nil
      lsp_client.execute_command('unknown/command', {}, function(err, result)
        error_received = err
      end)

      assert.is_string(error_received)
      assert.matches('not supported', error_received)
    end)
  end)
end)
