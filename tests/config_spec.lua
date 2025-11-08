-- Tests for configuration module

local config = require('kotlin-extended-lsp.config')

describe('config', function()
  before_each(function()
    -- Reset to defaults before each test
    config.current = vim.deepcopy(config.defaults)
  end)

  describe('setup', function()
    it('should merge user config with defaults', function()
      config.setup({
        enabled = false,
        silent_fallbacks = true,
      })

      assert.is_false(config.get_value('enabled'))
      assert.is_true(config.get_value('silent_fallbacks'))
      -- Default values should still be present
      assert.is_true(config.get_value('decompile_on_jar'))
    end)

    it('should reject invalid configuration', function()
      assert.has_error(function()
        config.setup({
          enabled = 'not a boolean', -- Should be boolean
        })
      end)
    end)

    it('should reject invalid log level', function()
      assert.has_error(function()
        config.setup({
          log = {
            level = 'invalid', -- Not in enum
          }
        })
      end)
    end)

    it('should reject out of range values', function()
      assert.has_error(function()
        config.setup({
          lsp = {
            timeout_ms = 50, -- Below minimum
          }
        })
      end)
    end)
  end)

  describe('get_value', function()
    it('should retrieve nested values', function()
      local value = config.get_value('lsp.timeout_ms')
      assert.equals(5000, value)
    end)

    it('should return nil for non-existent paths', function()
      local value = config.get_value('non.existent.path')
      assert.is_nil(value)
    end)
  end)

  describe('update', function()
    it('should update nested values', function()
      config.update('lsp.timeout_ms', 10000)
      assert.equals(10000, config.get_value('lsp.timeout_ms'))
    end)

    it('should create intermediate tables if needed', function()
      config.update('new.nested.value', 'test')
      assert.equals('test', config.get_value('new.nested.value'))
    end)
  end)
end)
