-- cache.lua
-- LRU (Least Recently Used) cache implementation for decompiled content

local M = {}

-- Cache entry structure: { content, timestamp, access_count, last_access }
local cache_data = {}
local cache_order = {} -- LRU order tracking (most recent first)
local cache_size = 0

-- Default configuration
local config = {
  max_size = 50, -- Maximum number of entries
  ttl = 3600, -- Time-to-live in seconds
}

-- Initialize cache with configuration
function M.setup(opts)
  opts = opts or {}
  config.max_size = opts.max_size or config.max_size
  config.ttl = opts.ttl or config.ttl
end

-- Update LRU order
local function update_lru(uri)
  -- Remove uri from current position
  for i, cached_uri in ipairs(cache_order) do
    if cached_uri == uri then
      table.remove(cache_order, i)
      break
    end
  end

  -- Add to front (most recently used)
  table.insert(cache_order, 1, uri)
end

-- Evict least recently used entry
local function evict_lru()
  if #cache_order == 0 then
    return
  end

  -- Remove oldest (last in list)
  local oldest_uri = table.remove(cache_order)
  if oldest_uri and cache_data[oldest_uri] then
    cache_data[oldest_uri] = nil
    cache_size = cache_size - 1
  end
end

-- Enforce cache size limit
local function enforce_limit()
  while cache_size > config.max_size do
    evict_lru()
  end
end

-- Check if entry is expired
local function is_expired(entry)
  if not entry or not entry.timestamp then
    return true
  end

  return (os.time() - entry.timestamp) > config.ttl
end

-- Get entry from cache
function M.get(uri)
  if not uri or type(uri) ~= 'string' then
    return nil
  end

  local entry = cache_data[uri]
  if not entry then
    return nil
  end

  -- Check expiration
  if is_expired(entry) then
    M.remove(uri)
    return nil
  end

  -- Update access metadata
  entry.access_count = (entry.access_count or 0) + 1
  entry.last_access = os.time()
  update_lru(uri)

  return entry.content
end

-- Put entry into cache
function M.put(uri, content)
  if not uri or type(uri) ~= 'string' then
    return false
  end

  if not content or type(content) ~= 'string' then
    return false
  end

  -- Check if entry already exists
  local exists = cache_data[uri] ~= nil

  -- Create or update entry
  cache_data[uri] = {
    content = content,
    timestamp = os.time(),
    access_count = 1,
    last_access = os.time(),
  }

  if not exists then
    cache_size = cache_size + 1
  end

  update_lru(uri)
  enforce_limit()

  return true
end

-- Remove entry from cache
function M.remove(uri)
  if not uri or not cache_data[uri] then
    return false
  end

  cache_data[uri] = nil
  cache_size = cache_size - 1

  -- Remove from LRU order
  for i, cached_uri in ipairs(cache_order) do
    if cached_uri == uri then
      table.remove(cache_order, i)
      break
    end
  end

  return true
end

-- Clear entire cache
function M.clear()
  local count = cache_size
  cache_data = {}
  cache_order = {}
  cache_size = 0
  return count
end

-- Clean expired entries
function M.clean_expired()
  local removed = 0
  local to_remove = {}

  for uri, entry in pairs(cache_data) do
    if is_expired(entry) then
      table.insert(to_remove, uri)
    end
  end

  for _, uri in ipairs(to_remove) do
    if M.remove(uri) then
      removed = removed + 1
    end
  end

  return removed
end

-- Get cache statistics
function M.stats()
  return {
    size = cache_size,
    max_size = config.max_size,
    ttl = config.ttl,
    entries = vim.tbl_map(function(uri)
      local entry = cache_data[uri]
      return {
        uri = uri,
        size = #entry.content,
        age = os.time() - entry.timestamp,
        access_count = entry.access_count,
        last_access_ago = os.time() - entry.last_access,
      }
    end, cache_order),
  }
end

-- Get cache size (number of entries)
function M.size()
  return cache_size
end

-- Check if cache contains uri
function M.has(uri)
  return cache_data[uri] ~= nil and not is_expired(cache_data[uri])
end

return M
