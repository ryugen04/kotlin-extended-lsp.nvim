-- Tests for decompile module

local config = require('kotlin-extended-lsp.config')
local decompile = require('kotlin-extended-lsp.decompile')

describe('decompile', function()
  before_each(function()
    config.setup({}) -- Use defaults
    decompile.clear_cache()

    -- Clean up all buffers to prevent conflicts
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
    end
  end)

  describe('is_compiled_file', function()
    it('should detect JAR file URIs', function()
      assert.is_true(
        decompile.is_compiled_file('jar:file:///path/to/lib.jar!/com/example/Class.class')
      )
      assert.is_true(
        decompile.is_compiled_file('jar:file:///usr/lib/kotlin.jar!/kotlin/String.class')
      )
    end)

    it('should detect class file URIs', function()
      assert.is_true(decompile.is_compiled_file('file:///path/to/Class.class'))
      assert.is_true(decompile.is_compiled_file('file:///build/classes/Main.class'))
    end)

    it('should reject Kotlin source files', function()
      assert.is_false(decompile.is_compiled_file('file:///path/to/File.kt'))
      assert.is_false(decompile.is_compiled_file('file:///src/Main.kt'))
    end)

    it('should reject Java source files', function()
      assert.is_false(decompile.is_compiled_file('file:///path/to/File.java'))
    end)

    it('should reject invalid inputs', function()
      assert.is_false(decompile.is_compiled_file(nil))
      assert.is_false(decompile.is_compiled_file(123))
      assert.is_false(decompile.is_compiled_file({}))
      assert.is_false(decompile.is_compiled_file(''))
    end)

    it('should reject excessively long URIs', function()
      local long_uri = 'file://' .. string.rep('a', 5000) .. '.class'
      assert.is_false(decompile.is_compiled_file(long_uri))
    end)

    it('should reject path traversal attempts', function()
      assert.is_false(decompile.is_compiled_file('file:///../../../etc/passwd.class'))
      assert.is_false(decompile.is_compiled_file('jar:file:///../lib.jar!/Class.class'))
    end)

    it('should reject URIs with control characters', function()
      assert.is_false(decompile.is_compiled_file('file:///path\x00/Class.class'))
      assert.is_false(decompile.is_compiled_file('file:///path\r\n/Class.class'))
    end)

    it('should reject invalid URI schemes', function()
      assert.is_false(decompile.is_compiled_file('http://example.com/Class.class'))
      assert.is_false(decompile.is_compiled_file('ftp://server/Class.class'))
      assert.is_false(decompile.is_compiled_file('custom://path/Class.class'))
    end)

    it('should require .class extension', function()
      assert.is_false(decompile.is_compiled_file('file:///path/to/file.txt'))
      assert.is_false(decompile.is_compiled_file('jar:file:///lib.jar!/NoExtension'))
    end)
  end)

  describe('cache management', function()
    it('should clear cache', function()
      decompile.clear_cache()
      -- Should not throw errors
    end)

    it('should return cache statistics', function()
      local stats = decompile.cache_stats()
      assert.is_table(stats)
      assert.is_number(stats.size)
      assert.is_number(stats.max_size)
      assert.is_number(stats.ttl)
    end)

    it('should clean expired entries', function()
      local removed = decompile.clean_cache()
      assert.is_number(removed)
      assert.is_true(removed >= 0)
    end)
  end)

  describe('show_decompiled', function()
    it('should create buffer with content', function()
      local uri = 'jar:file:///test.jar!/Test.class'
      local content = 'public class Test {\n  // Decompiled\n}'

      local bufnr, err = decompile.show_decompiled(uri, content, { silent = true, no_focus = true })
      assert.is_nil(err)
      assert.is_number(bufnr)
      assert.is_true(bufnr > 0)

      -- Verify buffer properties
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
      assert.equals('nofile', vim.bo[bufnr].buftype)
      assert.is_false(vim.bo[bufnr].modifiable)
      assert.is_true(vim.bo[bufnr].readonly)

      -- Clean up
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should reject content exceeding max size', function()
      config.setup({
        performance = {
          max_file_size = 100, -- Very small limit
        },
      })

      local uri = 'jar:file:///test.jar!/Test.class'
      local large_content = string.rep('a', 200) -- Exceeds limit

      local bufnr, err = decompile.show_decompiled(uri, large_content, { silent = true })
      assert.is_nil(bufnr)
      assert.is_string(err)
      assert.matches('too large', err)
    end)

    it('should set filetype when syntax highlighting enabled', function()
      config.setup({
        decompile = {
          syntax_highlight = true,
        },
      })

      local uri = 'jar:file:///test.jar!/Test.class'
      local content = 'class Test {}'

      local bufnr, err = decompile.show_decompiled(uri, content, { silent = true, no_focus = true })
      assert.is_nil(err)
      assert.equals('kotlin', vim.bo[bufnr].filetype)

      -- Clean up
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should reuse existing buffer for same URI', function()
      local uri = 'jar:file:///test.jar!/Test.class'
      local content1 = 'first content'
      local content2 = 'second content'

      local bufnr1, _ = decompile.show_decompiled(uri, content1, { silent = true, no_focus = true })
      assert.is_not_nil(bufnr1)

      -- Wait a bit to ensure buffer is fully created
      vim.wait(10)

      local bufnr2, _ = decompile.show_decompiled(uri, content2, { silent = true, no_focus = true })
      assert.is_not_nil(bufnr2)

      -- Should reuse same buffer
      assert.equals(bufnr1, bufnr2)

      -- Clean up
      if bufnr1 then
        vim.api.nvim_buf_delete(bufnr1, { force = true })
      end
    end)
  end)

  describe('decompile_uri with mocked LSP', function()
    local original_lsp_client
    local original_decompile

    before_each(function()
      original_lsp_client = package.loaded['kotlin-extended-lsp.lsp_client']
      original_decompile = package.loaded['kotlin-extended-lsp.decompile']

      -- Mock LSP client
      package.loaded['kotlin-extended-lsp.lsp_client'] = {
        get_kotlin_client = function()
          return { id = 1, name = 'kotlin_lsp' }
        end,
        is_attached = function()
          return true
        end,
        supports_method = function()
          return true
        end,
        supports_custom_command = function(cmd)
          return cmd == 'kotlin/jarClassContents'
        end,
        request = function(method, params, handler)
          -- Simulate successful decompile
          if method == 'kotlin/jarClassContents' then
            vim.defer_fn(function()
              handler(nil, 'public class Test {}')
            end, 10)
          end
        end,
      }

      -- Reload decompile module to use mocked lsp_client
      package.loaded['kotlin-extended-lsp.decompile'] = nil
      decompile = require('kotlin-extended-lsp.decompile')
    end)

    after_each(function()
      package.loaded['kotlin-extended-lsp.lsp_client'] = original_lsp_client
      package.loaded['kotlin-extended-lsp.decompile'] = original_decompile
      decompile = require('kotlin-extended-lsp.decompile')
    end)

    it('should reject non-compiled files', function()
      local called = false
      decompile.decompile_uri('file:///test.kt', function(err, result)
        called = true
        assert.is_string(err)
        assert.is_nil(result)
      end)

      assert.is_true(called)
    end)

    it('should use cache when available', function()
      config.setup({ performance = { cache_enabled = true } })

      local uri = 'jar:file:///test.jar!/Test.class'
      local call_count = 0

      -- First call - should hit LSP
      decompile.decompile_uri(uri, function(err, result)
        call_count = call_count + 1
      end)

      vim.wait(50)

      -- Second call - should use cache
      local cached_call = false
      decompile.decompile_uri(uri, function(err, result)
        cached_call = true
        assert.is_nil(err)
        assert.is_string(result)
      end)

      -- Cached result should be immediate
      assert.is_true(cached_call)
    end)
  end)
end)
