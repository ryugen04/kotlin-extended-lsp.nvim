-- Tests for logger module

local logger = require('kotlin-extended-lsp.logger')

describe('logger', function()
  local test_log_file = vim.fn.tempname()

  before_each(function()
    -- Reset logger with test configuration
    logger.setup({
      level = logger.levels.TRACE,
      use_console = false,
      use_file = true,
      file_path = test_log_file,
    })
  end)

  after_each(function()
    logger.close()
    -- Clean up test file
    pcall(vim.fn.delete, test_log_file)
  end)

  describe('setup', function()
    it('should create log file when use_file is true', function()
      logger.setup({
        use_file = true,
        file_path = test_log_file,
      })

      logger.info('test message')
      logger.close()

      -- File should exist
      assert.equals(1, vim.fn.filereadable(test_log_file))
    end)

    it('should not create log file when use_file is false', function()
      local temp_file = vim.fn.tempname()
      logger.setup({
        use_file = false,
        file_path = temp_file,
      })

      logger.info('test message')
      logger.close()

      -- File should not exist
      assert.equals(0, vim.fn.filereadable(temp_file))
    end)

    it('should close previous file handle on re-setup', function()
      -- First setup
      logger.setup({
        use_file = true,
        file_path = test_log_file,
      })
      logger.info('first message')

      -- Re-setup (should close previous file)
      logger.setup({
        use_file = true,
        file_path = test_log_file,
      })
      logger.info('second message')

      logger.close()

      -- Should not cause errors
    end)
  end)

  describe('log levels', function()
    it('should respect log level threshold', function()
      logger.setup({
        level = logger.levels.WARN,
        use_file = true,
        file_path = test_log_file,
      })

      logger.trace('trace message')
      logger.debug('debug message')
      logger.info('info message')
      logger.warn('warn message')
      logger.error('error message')

      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')

      -- Should not contain trace, debug, info
      assert.is_nil(content:match('TRACE'))
      assert.is_nil(content:match('DEBUG'))
      assert.is_nil(content:match('INFO'))

      -- Should contain warn and error
      assert.matches('WARN.*warn message', content)
      assert.matches('ERROR.*error message', content)
    end)

    it('should log all levels when set to TRACE', function()
      logger.setup({
        level = logger.levels.TRACE,
        use_file = true,
        file_path = test_log_file,
      })

      logger.trace('trace message')
      logger.debug('debug message')
      logger.info('info message')
      logger.warn('warn message')
      logger.error('error message')

      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')

      assert.matches('TRACE.*trace message', content)
      assert.matches('DEBUG.*debug message', content)
      assert.matches('INFO.*info message', content)
      assert.matches('WARN.*warn message', content)
      assert.matches('ERROR.*error message', content)
    end)

    it('should not log anything when level is OFF', function()
      logger.setup({
        level = logger.levels.OFF,
        use_file = true,
        file_path = test_log_file,
      })

      logger.trace('trace message')
      logger.error('error message')

      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')

      -- Should only contain session markers
      assert.is_nil(content:match('trace message'))
      assert.is_nil(content:match('error message'))
    end)
  end)

  describe('log formatting', function()
    it('should include timestamp in log messages', function()
      logger.info('test message')
      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')
      assert.matches('%[%d%d:%d%d:%d%d%]', content) -- [HH:MM:SS]
    end)

    it('should include log level in messages', function()
      logger.info('info message')
      logger.warn('warn message')
      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')
      assert.matches('INFO', content)
      assert.matches('WARN', content)
    end)

    it('should include context when provided', function()
      logger.info('message with context', { uri = 'test://uri', count = 42 })
      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')
      assert.matches('message with context', content)
      assert.matches('uri', content)
      assert.matches('42', content)
    end)
  end)

  describe('lsp_request and lsp_response', function()
    it('should log LSP requests', function()
      logger.lsp_request('textDocument/definition', { position = { line = 10 } })
      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')
      assert.matches('LSP Request', content)
      assert.matches('textDocument/definition', content)
    end)

    it('should log successful LSP responses', function()
      logger.lsp_response('textDocument/definition', true, { uri = 'file://test' })
      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')
      assert.matches('LSP Response', content)
      assert.matches('success', content)
    end)

    it('should log failed LSP responses', function()
      logger.lsp_response('textDocument/definition', false, 'error message')
      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')
      assert.matches('LSP Response', content)
      assert.matches('error', content)
      assert.matches('error message', content)
    end)
  end)

  describe('close', function()
    it('should write session end marker', function()
      logger.info('test')
      logger.close()

      local content = table.concat(vim.fn.readfile(test_log_file), '\n')
      assert.matches('Session ended', content)
    end)

    it('should safely handle multiple close calls', function()
      logger.close()
      logger.close()
      -- Should not throw errors
    end)
  end)

  describe('console output', function()
    it('should use vim.notify when use_console is true', function()
      local notifications = {}
      local original_notify = vim.notify

      vim.notify = function(msg, level, opts)
        table.insert(notifications, { msg = msg, level = level, opts = opts })
      end

      logger.setup({
        level = logger.levels.INFO,
        use_console = true,
        use_file = false,
      })

      logger.info('console message')

      vim.notify = original_notify

      assert.is_true(#notifications > 0)
      local found = false
      for _, notif in ipairs(notifications) do
        if notif.msg:match('console message') then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)
end)
