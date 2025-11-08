-- config.lua
-- Configuration management with validation

local M = {}

-- Default configuration
M.defaults = {
  -- General settings
  enabled = true,

  -- Keymap settings
  auto_setup_keymaps = true,
  keymaps = {
    -- Navigation (ジャンプ機能)
    definition = 'gd',
    implementation = 'gi',
    type_definition = 'gy',
    declaration = 'gD',
    references = 'gr',

    -- Documentation (ドキュメント表示)
    hover = 'K',
    signature_help = '<C-k>',

    -- Editing (編集機能)
    rename = '<leader>rn',
    code_action = '<leader>ca',
    format = '<leader>f',

    -- Diagnostics (診断機能)
    goto_prev = '[d',
    goto_next = ']d',
    open_float = '<leader>e',
    setloclist = '<leader>q',
  },

  -- Behavior settings
  use_global_handlers = false,
  silent_fallbacks = false,
  decompile_on_jar = true,
  show_capabilities_on_attach = false,

  -- Decompile settings
  decompile = {
    show_line_numbers = true,
    syntax_highlight = true,
    auto_close_on_leave = false,
    prefer_source = true, -- Prefer source over decompiled when available
  },

  -- Performance settings
  performance = {
    debounce_ms = 100,
    max_file_size = 1024 * 1024, -- 1MB
    cache_enabled = true,
    cache_ttl = 3600, -- 1 hour
    max_cache_entries = 50, -- Maximum number of cached decompiled files
  },

  -- LSP settings
  lsp = {
    timeout_ms = 5000,
    retry_count = 3,
    retry_delay_ms = 500,
  },

  -- Logging settings
  log = {
    level = 'info', -- trace, debug, info, warn, error, off
    use_console = true,
    use_file = false,
    file_path = vim.fn.stdpath('cache') .. '/kotlin-extended-lsp.log',
  },

  -- UI settings
  ui = {
    float = {
      border = 'rounded',
      max_width = 100,
      max_height = 30,
    },
    signs = {
      decompiled = '󰘧',
      loading = '󰔟',
      error = '',
    },
  },
}

-- Current configuration
M.current = vim.deepcopy(M.defaults)

-- Validation schema
local schema = {
  enabled = { type = 'boolean' },
  auto_setup_keymaps = { type = 'boolean' },
  use_global_handlers = { type = 'boolean' },
  silent_fallbacks = { type = 'boolean' },
  decompile_on_jar = { type = 'boolean' },
  show_capabilities_on_attach = { type = 'boolean' },

  keymaps = {
    type = 'table',
    fields = {
      -- Navigation
      definition = { type = 'string', optional = true },
      implementation = { type = 'string', optional = true },
      type_definition = { type = 'string', optional = true },
      declaration = { type = 'string', optional = true },
      references = { type = 'string', optional = true },
      -- Documentation
      hover = { type = 'string', optional = true },
      signature_help = { type = 'string', optional = true },
      -- Editing
      rename = { type = 'string', optional = true },
      code_action = { type = 'string', optional = true },
      format = { type = 'string', optional = true },
      -- Diagnostics
      goto_prev = { type = 'string', optional = true },
      goto_next = { type = 'string', optional = true },
      open_float = { type = 'string', optional = true },
      setloclist = { type = 'string', optional = true },
    },
  },

  decompile = {
    type = 'table',
    fields = {
      show_line_numbers = { type = 'boolean' },
      syntax_highlight = { type = 'boolean' },
      auto_close_on_leave = { type = 'boolean' },
      prefer_source = { type = 'boolean' },
    },
  },

  performance = {
    type = 'table',
    fields = {
      debounce_ms = { type = 'number', min = 0 },
      max_file_size = { type = 'number', min = 0 },
      cache_enabled = { type = 'boolean' },
      cache_ttl = { type = 'number', min = 0 },
      max_cache_entries = { type = 'number', min = 1, max = 1000 },
    },
  },

  lsp = {
    type = 'table',
    fields = {
      timeout_ms = { type = 'number', min = 100 },
      retry_count = { type = 'number', min = 0, max = 10 },
      retry_delay_ms = { type = 'number', min = 0 },
    },
  },

  log = {
    type = 'table',
    fields = {
      level = { type = 'string', enum = { 'trace', 'debug', 'info', 'warn', 'error', 'off' } },
      use_console = { type = 'boolean' },
      use_file = { type = 'boolean' },
      file_path = { type = 'string' },
    },
  },

  ui = {
    type = 'table',
    fields = {
      float = {
        type = 'table',
        fields = {
          border = { type = 'string' },
          max_width = { type = 'number', min = 20 },
          max_height = { type = 'number', min = 10 },
        },
      },
      signs = {
        type = 'table',
        fields = {
          decompiled = { type = 'string' },
          loading = { type = 'string' },
          error = { type = 'string' },
        },
      },
    },
  },
}

-- Validate a value against schema
local function validate_value(value, schema_def, path)
  path = path or 'config'

  -- Check type
  local value_type = type(value)
  if schema_def.type and value_type ~= schema_def.type then
    return false, string.format('%s: expected %s, got %s', path, schema_def.type, value_type)
  end

  -- Check enum
  if schema_def.enum then
    local found = false
    for _, enum_value in ipairs(schema_def.enum) do
      if value == enum_value then
        found = true
        break
      end
    end
    if not found then
      return false, string.format('%s: must be one of %s', path, vim.inspect(schema_def.enum))
    end
  end

  -- Check min/max for numbers
  if schema_def.type == 'number' then
    if schema_def.min and value < schema_def.min then
      return false, string.format('%s: must be >= %d', path, schema_def.min)
    end
    if schema_def.max and value > schema_def.max then
      return false, string.format('%s: must be <= %d', path, schema_def.max)
    end
  end

  -- Check table fields
  if schema_def.type == 'table' and schema_def.fields then
    for field_name, field_schema in pairs(schema_def.fields) do
      local field_value = value[field_name]
      if field_value ~= nil then
        local ok, err = validate_value(field_value, field_schema, path .. '.' .. field_name)
        if not ok then
          return false, err
        end
      elseif not field_schema.optional then
        return false, string.format('%s.%s: required field missing', path, field_name)
      end
    end
  end

  return true
end

-- Validate configuration
function M.validate(config)
  for key, value in pairs(config) do
    local schema_def = schema[key]
    if schema_def then
      local ok, err = validate_value(value, schema_def, key)
      if not ok then
        return false, err
      end
    end
  end
  return true
end

-- Setup configuration
function M.setup(user_config)
  user_config = user_config or {}

  -- Merge with defaults first
  M.current = vim.tbl_deep_extend('force', M.defaults, user_config)

  -- Validate merged config to ensure all required fields are present
  local ok, err = M.validate(M.current)
  if not ok then
    error(string.format('Invalid configuration: %s', err))
  end

  return M.current
end

-- Get current configuration
function M.get()
  return M.current
end

-- Get specific config value with path
function M.get_value(path)
  local parts = vim.split(path, '.', { plain = true })
  local value = M.current

  for _, part in ipairs(parts) do
    if type(value) ~= 'table' then
      return nil
    end
    value = value[part]
  end

  return value
end

-- Update configuration at runtime
function M.update(path, value)
  local parts = vim.split(path, '.', { plain = true })
  local config = M.current

  for i = 1, #parts - 1 do
    local part = parts[i]
    if type(config[part]) ~= 'table' then
      config[part] = {}
    end
    config = config[part]
  end

  config[parts[#parts]] = value
end

return M
