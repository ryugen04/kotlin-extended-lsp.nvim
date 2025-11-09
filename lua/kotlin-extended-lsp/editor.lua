-- editor.lua
-- Editor settings and actions

local M = {}

local config = require('kotlin-extended-lsp.config')
local job = require('kotlin-extended-lsp.utils.job')
local logger = require('kotlin-extended-lsp.logger')

--- Find and parse .editorconfig file
--- @param filepath string File path
--- @return table|nil EditorConfig settings or nil
local function find_editorconfig(filepath)
  local dir = vim.fn.fnamemodify(filepath, ':h')

  while dir ~= '/' do
    local editorconfig_path = dir .. '/.editorconfig'
    if vim.fn.filereadable(editorconfig_path) == 1 then
      return editorconfig_path
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end

  return nil
end

--- Parse .editorconfig file (simple implementation)
--- @param filepath string Path to .editorconfig
--- @param target_file string Target file path
--- @return table Settings
local function parse_editorconfig(filepath, target_file)
  local settings = {}
  local lines = vim.fn.readfile(filepath)
  local current_section = nil
  local target_basename = vim.fn.fnamemodify(target_file, ':t')

  for _, line in ipairs(lines) do
    -- Skip comments and empty lines
    if not (line:match('^%s*[#;]') or line:match('^%s*$')) then
      -- Section header
      local section = line:match('^%[(.+)%]')
      if section then
        current_section = section
      else
        -- Key-value pair
        local key, value = line:match('^%s*([^=]+)%s*=%s*(.+)%s*$')
        if key and value then
          -- Check if current section matches target file
          if current_section and current_section:match('%*%.kt') then
            settings[key:lower()] = value:lower()
          end
        end
      end
    end
  end

  return settings
end

--- Apply EditorConfig settings to buffer
--- @param bufnr number Buffer number
--- @param settings table EditorConfig settings
local function apply_editorconfig(bufnr, settings)
  if not settings then
    return
  end

  -- Indent style
  if settings.indent_style == 'space' then
    vim.api.nvim_buf_set_option(bufnr, 'expandtab', true)
  elseif settings.indent_style == 'tab' then
    vim.api.nvim_buf_set_option(bufnr, 'expandtab', false)
  end

  -- Indent size
  if settings.indent_size then
    local size = tonumber(settings.indent_size)
    if size then
      vim.api.nvim_buf_set_option(bufnr, 'shiftwidth', size)
      vim.api.nvim_buf_set_option(bufnr, 'tabstop', size)
    end
  end

  -- Max line length
  if settings.max_line_length then
    local length = tonumber(settings.max_line_length)
    if length then
      vim.api.nvim_buf_set_option(bufnr, 'textwidth', length)
      vim.api.nvim_win_set_option(0, 'colorcolumn', tostring(length))
    end
  end

  -- Trim trailing whitespace
  if settings.trim_trailing_whitespace == 'true' then
    -- Will be handled by on_save action
  end

  -- Insert final newline
  if settings.insert_final_newline == 'true' then
    vim.api.nvim_buf_set_option(bufnr, 'fixendofline', true)
    vim.api.nvim_buf_set_option(bufnr, 'endofline', true)
  elseif settings.insert_final_newline == 'false' then
    vim.api.nvim_buf_set_option(bufnr, 'fixendofline', false)
  end

  logger.debug('Applied EditorConfig settings', { settings = settings })
end

--- Organize imports using LSP
--- @param bufnr number Buffer number
--- @param callback function|nil Callback (err)
function M.organize_imports(bufnr, callback)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  callback = callback or function() end

  -- Try LSP code action for organizing imports
  local params = vim.lsp.util.make_range_params()
  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr),
    only = { 'source.organizeImports' },
  }

  vim.lsp.buf_request(bufnr, 'textDocument/codeAction', params, function(err, result, ctx, _)
    if err then
      logger.debug('Organize imports not supported', { error = err })
      callback(err)
      return
    end

    if result and #result > 0 then
      -- Apply first organize imports action
      local action = result[1]
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, 'utf-8')
        logger.debug('Organized imports')
      end
      callback(nil)
    else
      logger.debug('No organize imports action available')
      callback('No action available')
    end
  end)
end

--- Trim trailing whitespace from buffer
--- @param bufnr number Buffer number
function M.trim_trailing_whitespace(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local modified = false

  for i, line in ipairs(lines) do
    local trimmed = line:gsub('%s+$', '')
    if trimmed ~= line then
      lines[i] = trimmed
      modified = true
    end
  end

  if modified then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    logger.debug('Trimmed trailing whitespace')
  end
end

--- Ensure final newline
--- @param bufnr number Buffer number
function M.ensure_final_newline(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines > 0 and lines[#lines] ~= '' then
    table.insert(lines, '')
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    logger.debug('Added final newline')
  end
end

--- Setup editor settings for buffer
--- @param bufnr number Buffer number
function M.setup_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cfg = config.get_value('editor')
  if not cfg then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' then
    return
  end

  -- Apply EditorConfig
  if cfg.editorconfig then
    local editorconfig_path = find_editorconfig(filepath)
    if editorconfig_path then
      local settings = parse_editorconfig(editorconfig_path, filepath)
      apply_editorconfig(bufnr, settings)
    end
  end

  -- Set max line length visual guide
  if cfg.max_line_length then
    vim.api.nvim_win_set_option(0, 'colorcolumn', tostring(cfg.max_line_length))
  end

  -- Setup on-save actions
  local group = vim.api.nvim_create_augroup('KotlinExtendedLspEditor_' .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd('BufWritePre', {
    group = group,
    buffer = bufnr,
    callback = function()
      -- Organize imports
      if cfg.organize_imports_on_save then
        M.organize_imports(bufnr, function(err)
          if err then
            logger.debug('Organize imports failed', { error = err })
          end
        end)
      end

      -- Trim trailing whitespace
      if cfg.trim_trailing_whitespace then
        M.trim_trailing_whitespace(bufnr)
      end

      -- Ensure final newline
      if cfg.insert_final_newline then
        M.ensure_final_newline(bufnr)
      end
    end,
  })

  logger.debug('Editor buffer setup complete', { buffer = bufnr })
end

--- Teardown editor settings for buffer
--- @param bufnr number Buffer number
function M.teardown_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ok = pcall(vim.api.nvim_del_augroup_by_name, 'KotlinExtendedLspEditor_' .. bufnr)
  if ok then
    logger.debug('Editor buffer teardown complete', { buffer = bufnr })
  end
end

return M
