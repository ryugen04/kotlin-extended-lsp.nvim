-- neotest adapter for kotlin-extended-lsp.nvim
-- JUnit and Kotest support for Kotlin testing

local async = require('neotest.async')
local lib = require('neotest.lib')

local M = {}

-- Gradleラッパー検出
local function find_gradle_wrapper(root_dir)
  local gradlew = root_dir .. '/gradlew'
  if vim.fn.filereadable(gradlew) == 1 then
    return gradlew
  end
  return 'gradle'
end

-- マルチモジュールプロジェクト対応
local function detect_module(file_path, root_dir)
  local build_file = vim.fs.find('build.gradle.kts', {
    upward = true,
    path = vim.fs.dirname(file_path),
    stop = root_dir
  })[1]

  if build_file then
    local module_root = vim.fn.fnamemodify(build_file, ':h')
    if module_root ~= root_dir then
      local relative_path = module_root:gsub('^' .. vim.pesc(root_dir) .. '/', '')
      local module_name = relative_path:gsub('/', ':')
      return ':' .. module_name
    end
  end
  return ''
end

-- プロジェクトルート検出
M.root = lib.files.match_root_pattern('settings.gradle.kts', 'settings.gradle', 'build.gradle.kts', 'build.gradle')

-- テストファイルかどうか判定
function M.is_test_file(file_path)
  -- src/test/kotlin配下、またはファイル名が*Test.ktで終わる
  return file_path:match('/src/test/') ~= nil or file_path:match('Test%.kt$') ~= nil
end

-- テストフィルター（特定のテストファイルのみを対象）
function M.filter_dir(name, rel_path, root)
  -- src/test/kotlinディレクトリのみを対象
  return rel_path:match('^src/test/kotlin') ~= nil
end

-- Treesitterクエリでテストポジションを検出
function M.discover_positions(path)
  local query = [[
    ; JUnit @Test annotation
    (function_declaration
      (modifiers
        (annotation
          (user_type (type_identifier) @annotation (#eq? @annotation "Test"))))
      name: (simple_identifier) @test.name) @test.definition

    ; Kotest test("name") { }
    (call_expression
      function: (simple_identifier) @func (#eq? @func "test")
      value_arguments: (value_arguments
        (value_argument
          (string_literal) @test.name))) @test.definition

    ; Class definitions (test suites)
    (class_declaration
      name: (type_identifier) @namespace.name) @namespace.definition
  ]]

  return lib.treesitter.parse_positions(path, query, {
    nested_tests = true,
    require_namespaces = false,
  })
end

-- Gradleテストコマンドを構築
function M.build_spec(args)
  local position = args.tree:data()
  local root = M.root(position.path)

  if not root then
    return nil
  end

  local gradlew = find_gradle_wrapper(root)
  local module = detect_module(position.path, root)

  -- テスト実行コマンドを構築
  local command = { gradlew }

  -- モジュール指定
  if module ~= '' then
    table.insert(command, module .. ':test')
  else
    table.insert(command, 'test')
  end

  -- テストフィルター
  if position.type == 'test' then
    -- 個別テスト実行
    local namespace = position.path:match('kotlin/(.+)%.kt$')
    if namespace then
      namespace = namespace:gsub('/', '.')
      local test_pattern = namespace .. '.' .. position.name
      table.insert(command, '--tests')
      table.insert(command, test_pattern)
    end
  elseif position.type == 'namespace' then
    -- クラス単位でのテスト実行
    local namespace = position.path:match('kotlin/(.+)%.kt$')
    if namespace then
      namespace = namespace:gsub('/', '.')
      table.insert(command, '--tests')
      table.insert(command, namespace)
    end
  end

  -- XML レポート出力を強制
  table.insert(command, '--rerun-tasks')

  return {
    command = table.concat(command, ' '),
    cwd = root,
    context = {
      results_path = root .. '/build/test-results/test',
      module = module,
    },
  }
end

-- JUnit XMLレポートをパース
local function parse_junit_xml(xml_path)
  local file = io.open(xml_path, 'r')
  if not file then
    return {}
  end

  local content = file:read('*all')
  file:close()

  local results = {}

  -- <testcase>要素を抽出
  for testcase in content:gmatch('<testcase(.-)</testcase>') do
    local classname = testcase:match('classname="([^"]+)"')
    local name = testcase:match('name="([^"]+)"')
    local time = testcase:match('time="([^"]+)"')

    if classname and name then
      local test_id = classname .. '.' .. name
      local status = 'passed'
      local message = nil
      local short = nil

      -- 失敗を検出
      local failure = testcase:match('<failure(.-)</failure>')
      if failure then
        status = 'failed'
        message = failure:match('message="([^"]+)"') or 'Test failed'
        short = message:match('^([^\n]+)')
      end

      -- スキップを検出
      if testcase:match('<skipped') then
        status = 'skipped'
      end

      results[test_id] = {
        status = status,
        short = short,
        errors = message and { { message = message } } or nil,
      }
    end
  end

  return results
end

-- テスト結果を収集
function M.results(spec, result, tree)
  local results = {}
  local results_path = spec.context.results_path

  if not results_path or vim.fn.isdirectory(results_path) == 0 then
    return {}
  end

  -- 全てのXMLファイルを読み込み
  local xml_files = vim.fn.globpath(results_path, 'TEST-*.xml', false, true)

  for _, xml_file in ipairs(xml_files) do
    local parsed = parse_junit_xml(xml_file)
    for test_id, test_result in pairs(parsed) do
      results[test_id] = test_result
    end
  end

  -- ツリーをトラバースして結果をマッピング
  local neotest_results = {}

  for _, node in tree:iter_nodes() do
    local data = node:data()

    if data.type == 'test' then
      -- テスト名からIDを構築
      local namespace = data.path:match('kotlin/(.+)%.kt$')
      if namespace then
        namespace = namespace:gsub('/', '.')
        local test_id = namespace .. '.' .. data.name

        if results[test_id] then
          neotest_results[data.id] = results[test_id]
        else
          -- 結果が見つからない場合はスキップ扱い
          neotest_results[data.id] = { status = 'skipped' }
        end
      end
    end
  end

  return neotest_results
end

-- アダプター情報
M.name = 'kotlin-extended-lsp'

return M
