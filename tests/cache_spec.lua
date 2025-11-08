-- Tests for cache module

local cache = require('kotlin-extended-lsp.cache')

describe('cache', function()
  before_each(function()
    cache.clear()
    cache.setup({ max_size = 5, ttl = 1 }) -- Small cache for testing
  end)

  after_each(function()
    cache.clear()
  end)

  describe('put and get', function()
    it('should store and retrieve values', function()
      assert.is_true(cache.put('uri1', 'content1'))
      assert.equals('content1', cache.get('uri1'))
    end)

    it('should return nil for non-existent keys', function()
      assert.is_nil(cache.get('non-existent'))
    end)

    it('should reject invalid inputs', function()
      assert.is_false(cache.put(nil, 'content'))
      assert.is_false(cache.put('uri', nil))
      assert.is_false(cache.put(123, 'content'))
      assert.is_false(cache.put('uri', 123))
    end)

    it('should update existing entries', function()
      cache.put('uri1', 'content1')
      cache.put('uri1', 'updated')
      assert.equals('updated', cache.get('uri1'))
      assert.equals(1, cache.size())
    end)
  end)

  describe('LRU eviction', function()
    it('should evict least recently used when full', function()
      -- Fill cache
      for i = 1, 5 do
        cache.put('uri' .. i, 'content' .. i)
      end
      assert.equals(5, cache.size())

      -- Access uri1 to make it recently used
      cache.get('uri1')

      -- Add new item, should evict uri2 (oldest unused)
      cache.put('uri6', 'content6')
      assert.equals(5, cache.size())
      assert.is_not_nil(cache.get('uri1')) -- Recently accessed
      assert.is_nil(cache.get('uri2')) -- Should be evicted
      assert.is_not_nil(cache.get('uri6')) -- New entry
    end)

    it('should maintain LRU order on access', function()
      cache.put('uri1', 'content1')
      cache.put('uri2', 'content2')
      cache.put('uri3', 'content3')

      -- Access in reverse order
      cache.get('uri3')
      cache.get('uri2')
      cache.get('uri1')

      -- Fill cache
      cache.put('uri4', 'content4')
      cache.put('uri5', 'content5')

      -- Add one more, should evict uri3 (least recently accessed)
      cache.put('uri6', 'content6')
      assert.is_nil(cache.get('uri3'))
    end)
  end)

  describe('TTL expiration', function()
    it('should expire old entries', function()
      -- Mock os.time to simulate expiration
      local original_time = os.time
      local mock_time = os.time()

      _G.os.time = function()
        return mock_time
      end

      cache.put('uri1', 'content1')
      assert.is_not_nil(cache.get('uri1'))

      -- Advance time beyond TTL
      mock_time = mock_time + 2

      assert.is_nil(cache.get('uri1'))

      -- Restore original os.time
      _G.os.time = original_time
    end)

    it('should clean expired entries', function()
      -- Mock os.time to simulate expiration
      local original_time = os.time
      local mock_time = os.time()

      _G.os.time = function()
        return mock_time
      end

      cache.put('uri1', 'content1')
      cache.put('uri2', 'content2')

      -- Advance time beyond TTL
      mock_time = mock_time + 2

      local removed = cache.clean_expired()
      assert.equals(2, removed)
      assert.equals(0, cache.size())

      -- Restore original os.time
      _G.os.time = original_time
    end)
  end)

  describe('remove', function()
    it('should remove specific entry', function()
      cache.put('uri1', 'content1')
      cache.put('uri2', 'content2')

      assert.is_true(cache.remove('uri1'))
      assert.equals(1, cache.size())
      assert.is_nil(cache.get('uri1'))
      assert.is_not_nil(cache.get('uri2'))
    end)

    it('should return false for non-existent entry', function()
      assert.is_false(cache.remove('non-existent'))
    end)
  end)

  describe('clear', function()
    it('should clear all entries', function()
      cache.put('uri1', 'content1')
      cache.put('uri2', 'content2')
      cache.put('uri3', 'content3')

      local count = cache.clear()
      assert.equals(3, count)
      assert.equals(0, cache.size())
    end)
  end)

  describe('has', function()
    it('should return true for existing entries', function()
      cache.put('uri1', 'content1')
      assert.is_true(cache.has('uri1'))
    end)

    it('should return false for non-existent entries', function()
      assert.is_false(cache.has('non-existent'))
    end)

    it('should return false for expired entries', function()
      -- Mock os.time to simulate expiration
      local original_time = os.time
      local mock_time = os.time()

      _G.os.time = function()
        return mock_time
      end

      cache.put('uri1', 'content1')

      -- Advance time beyond TTL
      mock_time = mock_time + 2

      assert.is_false(cache.has('uri1'))

      -- Restore original os.time
      _G.os.time = original_time
    end)
  end)

  describe('stats', function()
    it('should return cache statistics', function()
      cache.put('uri1', 'content1')
      cache.put('uri2', 'longer content here')

      local stats = cache.stats()
      assert.equals(2, stats.size)
      assert.equals(5, stats.max_size)
      assert.equals(1, stats.ttl)
      assert.equals(2, #stats.entries)

      -- Check entry details
      local entry1 = stats.entries[1]
      assert.is_not_nil(entry1.uri)
      assert.is_number(entry1.size)
      assert.is_number(entry1.age)
      assert.is_number(entry1.access_count)
    end)
  end)

  describe('access tracking', function()
    it('should track access count', function()
      cache.put('uri1', 'content1')
      cache.get('uri1')
      cache.get('uri1')
      cache.get('uri1')

      local stats = cache.stats()
      -- Initial put counts as 1 access, plus 3 gets
      assert.is_true(stats.entries[1].access_count >= 3)
    end)
  end)
end)
