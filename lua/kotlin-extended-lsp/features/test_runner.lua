-- Standalone test runner for kotlin-extended-lsp.nvim
-- Provides test execution without neotest dependency

local ts_utils = require('kotlin-extended-lsp.ts_utils')
local utils = require('kotlin-extended-lsp.utils')
local M = {}

-- Gradleラッパー検出
local function find_gradle_wrapper()
  local root = vim.fn.getcwd()
  local gradlew = root .. '/gradlew'
  if vim.fn.filereadable(gradlew) == 1 then
    return gradlew
  end
  return 'gradle'
end

-- マルチモジュールプロジェクト対応
local function detect_module(file_path)
  local root = vim.fn.getcwd()
  local build_file = vim.fs.find('build.gradle.kts', {
    upward = true,
    path = vim.fs.dirname(file_path),
    stop = root
  })[1]

  if build_file then
    local module_root = vim.fn.fnamemodify(build_file, ':h')
    if module_root ~= root then
      local relative_path = module_root:gsub('^' .. vim.pesc(root) .. '/', '')
      local module_name = relative_path:gsub('/', ':')
      return ':' .. module_name
    end
  end
  return ''
end

-- パッケージ名を抽出
local function extract_package_name(file_path)
  local namespace = file_path:match('kotlin/(.+)%.kt$')
  if namespace then
    return namespace:gsub('/', '.')
  end
  return nil
end

-- カーソル位置のテスト関数名を取得
local function get_test_at_cursor()
  if not ts_utils.is_treesitter_available() then
    return nil
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local node = ts_utils.get_node_at_cursor(bufnr)

  if not node then
    return nil
  end

  -- function_declaration ノードを探索
  while node do
    if node:type() == 'function_declaration' then
      -- @Test アノテーションがあるか確認
      local has_test_annotation = false
      for child in node:iter_children() do
        if child:type() == 'modifiers' then
          for annotation in child:iter_children() do
            if annotation:type() == 'annotation' then
              local annotation_text = vim.treesitter.get_node_text(annotation, bufnr)
              if annotation_text:match('@Test') then
                has_test_annotation = true
                break
              end
            end
          end
        end
      end

      if has_test_annotation then
        -- 関数名を取得
        for child in node:iter_children() do
          if child:type() == 'simple_identifier' then
            return vim.treesitter.get_node_text(child, bufnr)
          end
        end
      end
    end
    node = node:parent()
  end

  return nil
end

-- JUnit XMLレポートをパース
local function parse_junit_xml(xml_path)
  local file = io.open(xml_path, 'r')
  if not file then
    return {}
  end

  local content = file:read('*all')
  file:close()

  local results = {
    total = 0,
    passed = 0,
    failed = 0,
    skipped = 0,
    failures = {},
  }

  -- テストケース数を抽出
  local tests = content:match('<testsuite.-tests="([^"]+)"')
  local failures = content:match('<testsuite.-failures="([^"]+)"')
  local skipped = content:match('<testsuite.-skipped="([^"]+)"')

  results.total = tonumber(tests) or 0
  results.failed = tonumber(failures) or 0
  results.skipped = tonumber(skipped) or 0
  results.passed = results.total - results.failed - results.skipped

  -- 失敗したテストの詳細を抽出
  for testcase in content:gmatch('<testcase(.-)</testcase>') do
    local failure = testcase:match('<failure(.-)</failure>')
    if failure then
      local name = testcase:match('name="([^"]+)"')
      local classname = testcase:match('classname="([^"]+)"')
      local message = failure:match('message="([^"]+)"') or 'Test failed'

      table.insert(results.failures, {
        name = name,
        classname = classname,
        message = message,
      })
    end
  end

  return results
end

-- テスト結果をFloating Windowで表示
local function show_test_results(results)
  local lines = {}
  table.insert(lines, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  table.insert(lines, '  Test Results')
  table.insert(lines, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  table.insert(lines, '')
  table.insert(lines, string.format('  Total:   %d', results.total))
  table.insert(lines, string.format('  Passed:  %d', results.passed))
  table.insert(lines, string.format('  Failed:  %d', results.failed))
  table.insert(lines, string.format('  Skipped: %d', results.skipped))
  table.insert(lines, '')

  if #results.failures > 0 then
    table.insert(lines, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    table.insert(lines, '  Failures')
    table.insert(lines, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    table.insert(lines, '')

    for _, failure in ipairs(results.failures) do
      table.insert(lines, string.format('  %s.%s', failure.classname, failure.name))
      table.insert(lines, string.format('    %s', failure.message))
      table.insert(lines, '')
    end
  end

  -- Floating Windowを作成
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'kotlin-test-results')

  local width = 60
  local height = math.min(#lines + 2, 30)
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
  }

  local win = vim.api.nvim_open_win(buf, true, opts)
  vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal')

  -- qで閉じる
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
end

-- テストを実行
local function run_test(test_pattern, opts)
  opts = opts or {}

  local gradlew = find_gradle_wrapper()
  local module = detect_module(vim.fn.expand('%:p'))
  local root = vim.fn.getcwd()
  local results_path = root .. '/build/test-results/test'

  -- コマンドを構築
  local command = { gradlew }

  if module ~= '' then
    table.insert(command, module .. ':test')
  else
    table.insert(command, 'test')
  end

  if test_pattern then
    table.insert(command, '--tests')
    table.insert(command, test_pattern)
  end

  table.insert(command, '--rerun-tasks')

  local cmd_string = table.concat(command, ' ')

  vim.notify('Running tests: ' .. cmd_string, vim.log.levels.INFO)

  -- 非同期実行
  vim.fn.jobstart(cmd_string, {
    cwd = root,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code == 0 then
          vim.notify('All tests passed!', vim.log.levels.INFO)
        else
          vim.notify('Some tests failed', vim.log.levels.WARN)
        end

        -- 結果を表示
        local xml_files = vim.fn.globpath(results_path, 'TEST-*.xml', false, true)
        if #xml_files > 0 then
          local all_results = {
            total = 0,
            passed = 0,
            failed = 0,
            skipped = 0,
            failures = {},
          }

          for _, xml_file in ipairs(xml_files) do
            local results = parse_junit_xml(xml_file)
            all_results.total = all_results.total + results.total
            all_results.passed = all_results.passed + results.passed
            all_results.failed = all_results.failed + results.failed
            all_results.skipped = all_results.skipped + results.skipped

            for _, failure in ipairs(results.failures) do
              table.insert(all_results.failures, failure)
            end
          end

          show_test_results(all_results)
        end
      end)
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })
end

-- カーソル位置のテストを実行
function M.run_nearest()
  local file_path = vim.fn.expand('%:p')
  local package_name = extract_package_name(file_path)

  if not package_name then
    vim.notify('Could not extract package name', vim.log.levels.ERROR)
    return
  end

  local test_name = get_test_at_cursor()

  if not test_name then
    vim.notify('No test found at cursor', vim.log.levels.WARN)
    return
  end

  local test_pattern = package_name .. '.' .. test_name
  run_test(test_pattern)
end

-- ファイル全体のテストを実行
function M.run_file()
  local file_path = vim.fn.expand('%:p')
  local package_name = extract_package_name(file_path)

  if not package_name then
    vim.notify('Could not extract package name', vim.log.levels.ERROR)
    return
  end

  run_test(package_name)
end

-- 全テストを実行
function M.run_all()
  run_test(nil)
end

-- setup: コマンドとキーマップを設定
function M.setup(opts)
  opts = opts or {}

  -- コマンドを作成
  vim.api.nvim_create_user_command('KotlinTestNearest', function()
    M.run_nearest()
  end, {
    desc = 'Run test at cursor'
  })

  vim.api.nvim_create_user_command('KotlinTestFile', function()
    M.run_file()
  end, {
    desc = 'Run all tests in current file'
  })

  vim.api.nvim_create_user_command('KotlinTestAll', function()
    M.run_all()
  end, {
    desc = 'Run all tests in project'
  })

  -- キーマップ設定（オプション）
  if opts.setup_keymaps ~= false then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspTestRunner', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf
          local keymap_opts = { buffer = bufnr, silent = true }

          vim.keymap.set('n', '<leader>ktn', M.run_nearest,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Kotlin: Run nearest test'
            }))

          vim.keymap.set('n', '<leader>ktf', M.run_file,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Kotlin: Run file tests'
            }))

          vim.keymap.set('n', '<leader>kta', M.run_all,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Kotlin: Run all tests'
            }))
        end
      end
    })
  end
end

return M
