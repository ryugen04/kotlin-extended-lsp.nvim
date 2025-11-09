-- utils/job.lua
-- Async job execution utilities

local M = {}

local uv = vim.loop

--- Execute a command asynchronously
--- @param cmd string Command to execute
--- @param args table Command arguments
--- @param opts table Options
---   - cwd: string Working directory
---   - env: table Environment variables
---   - timeout: number Timeout in milliseconds
---   - on_stdout: function Callback for stdout data
---   - on_stderr: function Callback for stderr data
---   - on_exit: function Callback when process exits (code, signal)
--- @param callback function Completion callback (err, stdout, stderr, code)
function M.run(cmd, args, opts, callback)
  opts = opts or {}
  local stdout_chunks = {}
  local stderr_chunks = {}

  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local handle, pid
  handle, pid = uv.spawn(cmd, {
    args = args,
    stdio = { nil, stdout, stderr },
    cwd = opts.cwd,
    env = opts.env,
  }, function(code, signal)
    -- Close handles
    if stdout and not stdout:is_closing() then
      stdout:close()
    end
    if stderr and not stderr:is_closing() then
      stderr:close()
    end
    if handle and not handle:is_closing() then
      handle:close()
    end

    -- Call completion callback
    vim.schedule(function()
      local stdout_str = table.concat(stdout_chunks, '')
      local stderr_str = table.concat(stderr_chunks, '')

      if code ~= 0 then
        callback(
          stderr_str ~= '' and stderr_str or ('Process exited with code ' .. code),
          stdout_str,
          stderr_str,
          code
        )
      else
        callback(nil, stdout_str, stderr_str, code)
      end

      if opts.on_exit then
        opts.on_exit(code, signal)
      end
    end)
  end)

  if not handle then
    callback('Failed to spawn process: ' .. (pid or 'unknown error'), '', '', -1)
    return
  end

  -- Setup timeout
  if opts.timeout then
    local timer = uv.new_timer()
    timer:start(opts.timeout, 0, function()
      if handle and not handle:is_closing() then
        handle:kill('sigterm')
      end
      timer:stop()
      timer:close()
      callback('Process timeout after ' .. opts.timeout .. 'ms', '', '', -1)
    end)
  end

  -- Read stdout
  if stdout then
    stdout:read_start(function(err, data)
      if err then
        callback('Error reading stdout: ' .. err, '', '', -1)
      elseif data then
        table.insert(stdout_chunks, data)
        if opts.on_stdout then
          vim.schedule(function()
            opts.on_stdout(data)
          end)
        end
      end
    end)
  end

  -- Read stderr
  if stderr then
    stderr:read_start(function(err, data)
      if err then
        callback('Error reading stderr: ' .. err, '', '', -1)
      elseif data then
        table.insert(stderr_chunks, data)
        if opts.on_stderr then
          vim.schedule(function()
            opts.on_stderr(data)
          end)
        end
      end
    end)
  end

  return handle, pid
end

--- Find executable in PATH or project
--- @param cmd string Command name
--- @param project_paths table|nil Optional project-specific paths to check first
--- @return string|nil Full path to executable or nil if not found
function M.find_executable(cmd, project_paths)
  -- Check project-specific paths first
  if project_paths then
    for _, path in ipairs(project_paths) do
      if vim.fn.executable(path) == 1 then
        return path
      end
    end
  end

  -- Check in PATH
  if vim.fn.executable(cmd) == 1 then
    return cmd
  end

  return nil
end

--- Check if a command is available
--- @param cmd string Command to check
--- @param project_paths table|nil Optional project-specific paths
--- @return boolean
function M.is_available(cmd, project_paths)
  return M.find_executable(cmd, project_paths) ~= nil
end

--- Get project root directory
--- @param bufnr number|nil Buffer number (default: current buffer)
--- @return string|nil Project root or nil
function M.get_project_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == '' then
    return nil
  end

  -- Look for common project markers
  local markers = {
    '.git',
    'build.gradle.kts',
    'build.gradle',
    'settings.gradle.kts',
    'settings.gradle',
    'pom.xml',
    'gradlew',
  }

  local dir = vim.fn.fnamemodify(filepath, ':h')
  while dir ~= '/' do
    for _, marker in ipairs(markers) do
      if
        vim.fn.isdirectory(dir .. '/' .. marker) == 1
        or vim.fn.filereadable(dir .. '/' .. marker) == 1
      then
        return dir
      end
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end

  return nil
end

--- Debounce a function
--- @param fn function Function to debounce
--- @param ms number Debounce delay in milliseconds
--- @return function Debounced function
function M.debounce(fn, ms)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      timer:stop()
      timer:close()
    end
    timer = uv.new_timer()
    timer:start(ms, 0, function()
      timer:stop()
      timer:close()
      timer = nil
      vim.schedule_wrap(fn)(unpack(args))
    end)
  end
end

--- Throttle a function
--- @param fn function Function to throttle
--- @param ms number Throttle interval in milliseconds
--- @return function Throttled function
function M.throttle(fn, ms)
  local timer = nil
  local running = false
  return function(...)
    if running then
      return
    end
    running = true
    local args = { ... }
    timer = uv.new_timer()
    timer:start(ms, 0, function()
      timer:stop()
      timer:close()
      timer = nil
      running = false
    end)
    vim.schedule_wrap(fn)(unpack(args))
  end
end

return M
