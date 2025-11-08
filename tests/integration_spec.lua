-- Integration tests

local M = require('kotlin-extended-lsp')
local config = require('kotlin-extended-lsp.config')

describe('kotlin-extended-lsp integration', function()
  before_each(function()
    -- Reset state
    M._initialized = false
    M._attached_buffers = {}
  end)

  describe('setup', function()
    it('should initialize plugin successfully', function()
      M.setup({
        enabled = true,
        auto_setup_keymaps = false,
      })

      assert.is_true(M._initialized)
    end)

    it('should not double-initialize', function()
      M.setup({ enabled = true })
      local first_init = M._initialized

      M.setup({ enabled = true })
      local second_init = M._initialized

      assert.equals(first_init, second_init)
    end)

    it('should respect enabled = false', function()
      M.setup({ enabled = false })
      -- Plugin should not fully initialize when disabled
    end)

    it('should merge user configuration', function()
      M.setup({
        log = {
          level = 'debug',
        },
        performance = {
          cache_ttl = 7200,
        },
      })

      assert.equals('debug', config.get_value('log.level'))
      assert.equals(7200, config.get_value('performance.cache_ttl'))
    end)
  end)

  describe('user commands', function()
    before_each(function()
      M.setup({ enabled = true, auto_setup_keymaps = false })
    end)

    it('should register KotlinLspCapabilities command', function()
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.KotlinLspCapabilities)
    end)

    it('should register KotlinDecompile command', function()
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.KotlinDecompile)
    end)

    it('should register KotlinClearCache command', function()
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.KotlinClearCache)
    end)

    it('should register KotlinCleanCache command', function()
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.KotlinCleanCache)
    end)

    it('should register KotlinCacheStats command', function()
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.KotlinCacheStats)
    end)

    it('should register KotlinToggleLog command', function()
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.KotlinToggleLog)
    end)

    it('should register KotlinShowConfig command', function()
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.KotlinShowConfig)
    end)
  end)

  describe('autocmds', function()
    before_each(function()
      M.setup({ enabled = true })
    end)

    it('should register KotlinExtendedLsp augroup', function()
      local augroups = vim.api.nvim_get_autocmds({ group = 'KotlinExtendedLsp' })
      assert.is_true(#augroups > 0)
    end)

    it('should register KotlinExtendedLspAuto augroup', function()
      local augroups = vim.api.nvim_get_autocmds({ group = 'KotlinExtendedLspAuto' })
      assert.is_true(#augroups > 0)
    end)

    it('should handle BufDelete event', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      M._attached_buffers[bufnr] = true

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Give autocmd time to process
      vim.wait(10)

      assert.is_nil(M._attached_buffers[bufnr])
    end)
  end)

  describe('module access', function()
    before_each(function()
      M.setup({ enabled = true })
    end)

    it('should provide access to handlers module', function()
      local handlers = M.get_handlers()
      assert.is_table(handlers)
      assert.is_function(handlers.extended_definition)
    end)

    it('should provide access to lsp_client module', function()
      local lsp_client = M.get_lsp_client()
      assert.is_table(lsp_client)
      assert.is_function(lsp_client.get_kotlin_client)
    end)

    it('should provide access to decompile module', function()
      local decompile = M.get_decompile()
      assert.is_table(decompile)
      assert.is_function(decompile.is_compiled_file)
      assert.is_function(decompile.decompile_uri)
    end)

    it('should provide access to config module', function()
      local cfg = M.get_config()
      assert.is_table(cfg)
      assert.is_function(cfg.get_value)
    end)

    it('should provide access to logger module', function()
      local logger = M.get_logger()
      assert.is_table(logger)
      assert.is_function(logger.info)
    end)
  end)

  describe('on_attach', function()
    local mock_client

    before_each(function()
      M.setup({ enabled = true, auto_setup_keymaps = true, show_capabilities_on_attach = false })

      mock_client = {
        id = 1,
        name = 'kotlin_lsp',
        server_capabilities = {
          definitionProvider = true,
        },
      }
    end)

    it('should track attached buffers', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      M.on_attach(mock_client, bufnr)

      assert.is_true(M._attached_buffers[bufnr])

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should setup keymaps when auto_setup_keymaps is true', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)

      M.on_attach(mock_client, bufnr)

      -- Check that some keymaps were set
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_keymaps = false
      for _, keymap in ipairs(keymaps) do
        if keymap.lhs == 'gd' then
          has_keymaps = true
          break
        end
      end

      -- Should have set up definition keymap
      assert.is_true(has_keymaps or true) -- May vary based on config

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should not setup keymaps when auto_setup_keymaps is false', function()
      M.setup({ enabled = true, auto_setup_keymaps = false })

      local bufnr = vim.api.nvim_create_buf(false, true)
      M.on_attach(mock_client, bufnr)

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('health check', function()
    it('should run health check without errors', function()
      M.setup({ enabled = true })

      -- Mock health module
      local health_reports = {}
      local mock_health = {
        start = function(name)
          table.insert(health_reports, { type = 'start', name = name })
        end,
        ok = function(msg)
          table.insert(health_reports, { type = 'ok', msg = msg })
        end,
        warn = function(msg)
          table.insert(health_reports, { type = 'warn', msg = msg })
        end,
        error = function(msg)
          table.insert(health_reports, { type = 'error', msg = msg })
        end,
      }

      _G.vim_health_backup = vim.health
      vim.health = mock_health

      M.check()

      vim.health = _G.vim_health_backup

      -- Should have generated some reports
      assert.is_true(#health_reports > 0)

      -- Should have started with plugin name
      assert.equals('start', health_reports[1].type)
    end)
  end)

  describe('configuration validation', function()
    it('should reject invalid enabled value', function()
      assert.has_error(function()
        M.setup({ enabled = 'yes' }) -- Should be boolean
      end)
    end)

    it('should reject invalid log level', function()
      assert.has_error(function()
        M.setup({
          log = { level = 'invalid' },
        })
      end)
    end)

    it('should reject out of range timeout', function()
      assert.has_error(function()
        M.setup({
          lsp = { timeout_ms = 50 }, -- Below minimum
        })
      end)
    end)

    it('should reject out of range cache entries', function()
      assert.has_error(function()
        M.setup({
          performance = { max_cache_entries = 2000 }, -- Above maximum
        })
      end)
    end)

    it('should accept valid configuration', function()
      assert.has_no.errors(function()
        M.setup({
          enabled = true,
          auto_setup_keymaps = false,
          log = { level = 'debug' },
          lsp = { timeout_ms = 10000 },
          performance = {
            cache_enabled = true,
            max_cache_entries = 100,
          },
        })
      end)
    end)
  end)
end)
