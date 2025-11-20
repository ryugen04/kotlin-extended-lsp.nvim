-- kotlin-extended-lsp.nvim Public API
-- which-keyや他のプラグインから呼び出すための公開API

local M = {}

-- 各機能モジュールを遅延ロード
local function get_ts_definition()
  return require('kotlin-extended-lsp.features.ts_definition')
end

local function get_decompile()
  return require('kotlin-extended-lsp.features.decompile')
end

local function get_type_definition()
  return require('kotlin-extended-lsp.features.type_definition')
end

local function get_implementation()
  return require('kotlin-extended-lsp.features.implementation')
end

local function get_declaration()
  return require('kotlin-extended-lsp.features.declaration')
end

local function get_commands()
  return require('kotlin-extended-lsp.features.commands')
end

local function get_test_runner()
  return require('kotlin-extended-lsp.features.test_runner')
end

local function get_refactor()
  return require('kotlin-extended-lsp.features.refactor')
end

-- ジャンプ機能
-- ==================

--- 定義へジャンプ（Treesitter + LSP + Decompile対応）
function M.goto_definition()
  get_ts_definition().goto_definition()
end

--- 型定義へジャンプ（Treesitter + LSP対応）
function M.goto_type_definition()
  get_ts_definition().goto_type_definition()
end

--- 実装へジャンプ
function M.goto_implementation()
  get_ts_definition().goto_implementation()
end

--- 宣言へジャンプ
function M.goto_declaration()
  get_ts_definition().goto_declaration()
end

-- LSP基本機能
-- ==================

--- シグネチャヘルプ（関数パラメータ情報を表示）
function M.signature_help()
  vim.lsp.buf.signature_help()
end

-- デコンパイル機能
-- ==================

--- カーソル位置のシンボルをデコンパイル
function M.decompile()
  get_decompile().decompile_under_cursor()
end

--- 指定URIをデコンパイル
---@param uri string JAR内ファイルのURI
function M.decompile_uri(uri)
  get_decompile().decompile_uri(uri)
end

--- デコンパイルキャッシュをクリア
function M.clear_decompile_cache()
  get_decompile().clear_cache()
end

--- LSPキャッシュをクリア（起動高速化用）
function M.clear_lsp_cache()
  local optimizer = require('kotlin-extended-lsp.features.startup_optimizer')
  optimizer.clear_cache()
end

-- カスタムコマンド
-- ==================

--- インポートを整理
function M.organize_imports()
  get_commands().organize_imports()
end

--- ワークスペースをエクスポート
function M.export_workspace()
  get_commands().export_workspace()
end

--- 診断を修正
function M.apply_fix()
  get_commands().apply_diagnostic_fix()
end

-- テスト機能
-- ==================

--- カーソル位置のテストを実行
function M.test_nearest()
  get_test_runner().run_nearest()
end

--- ファイル全体のテストを実行
function M.test_file()
  get_test_runner().run_file()
end

--- 全テストを実行
function M.test_all()
  get_test_runner().run_all()
end

-- リファクタリング機能
-- ==================

--- Code Actions（改善版UI）
function M.code_actions()
  get_refactor().code_actions()
end

--- Refactorメニュー
function M.refactor()
  get_refactor().code_actions_refactor()
end

--- Extract Variable
function M.extract_variable()
  get_refactor().extract_variable()
end

--- Inline Variable
function M.inline_variable()
  get_refactor().inline_variable()
end

-- which-key統合用のグループ定義
-- ==================

--- which-keyのためのキーマップ定義を取得
---@return table which-keyのキーマップ定義
function M.get_which_key_mappings()
  return {
    name = "Kotlin LSP",
    -- ジャンプ機能
    d = { M.goto_definition, "Go to Definition (TS+LSP)" },
    y = { M.goto_type_definition, "Go to Type Definition" },
    i = { M.goto_implementation, "Go to Implementation" },
    D = { M.goto_declaration, "Go to Declaration" },

    -- デコンパイル
    k = {
      name = "Kotlin",
      d = { M.decompile, "Decompile" },
      c = { M.clear_decompile_cache, "Clear Cache" },
      o = { M.organize_imports, "Organize Imports" },
      e = { M.export_workspace, "Export Workspace" },
      f = { M.apply_fix, "Apply Fix" },
      t = {
        name = "Test",
        n = { M.test_nearest, "Run Nearest Test" },
        f = { M.test_file, "Run File Tests" },
        a = { M.test_all, "Run All Tests" },
      },
      r = { M.refactor, "Refactor Menu" },
      a = { M.code_actions, "Code Actions" },
      e = {
        name = "Extract",
        v = { M.extract_variable, "Extract Variable" },
      },
      i = {
        name = "Inline",
        v = { M.inline_variable, "Inline Variable" },
      },
    },
  }
end

--- which-key v3用のキーマップ定義を取得
---@return table which-key v3のspec形式
function M.get_which_key_spec()
  return {
    { "gd", M.goto_definition, desc = "Go to Definition (TS+LSP)", mode = "n" },
    { "gy", M.goto_type_definition, desc = "Go to Type Definition", mode = "n" },
    { "gi", M.goto_implementation, desc = "Go to Implementation", mode = "n" },
    { "gD", M.goto_declaration, desc = "Go to Declaration", mode = "n" },
    { "<C-k>", M.signature_help, desc = "Signature Help", mode = "i" },

    { "<leader>k", group = "Kotlin" },
    { "<leader>kd", M.decompile, desc = "Decompile", mode = "n" },
    { "<leader>kc", M.clear_decompile_cache, desc = "Clear Cache", mode = "n" },
    { "<leader>ko", M.organize_imports, desc = "Organize Imports", mode = "n" },
    { "<leader>ke", M.export_workspace, desc = "Export Workspace", mode = "n" },
    { "<leader>kf", M.apply_fix, desc = "Apply Fix", mode = "n" },

    { "<leader>kt", group = "Test" },
    { "<leader>ktn", M.test_nearest, desc = "Run Nearest Test", mode = "n" },
    { "<leader>ktf", M.test_file, desc = "Run File Tests", mode = "n" },
    { "<leader>kta", M.test_all, desc = "Run All Tests", mode = "n" },

    { "<leader>kr", M.refactor, desc = "Refactor Menu", mode = "n" },
    { "<leader>ka", M.code_actions, desc = "Code Actions", mode = "n" },
    { "<leader>kev", M.extract_variable, desc = "Extract Variable", mode = "v" },
    { "<leader>kiv", M.inline_variable, desc = "Inline Variable", mode = "n" },
  }
end

--- Telescope統合用の関数リストを取得
---@return table Telescope用のpicker設定
function M.get_telescope_actions()
  return {
    { name = "Go to Definition (TS+LSP)", action = M.goto_definition },
    { name = "Go to Type Definition", action = M.goto_type_definition },
    { name = "Go to Implementation", action = M.goto_implementation },
    { name = "Go to Declaration", action = M.goto_declaration },
    { name = "Signature Help", action = M.signature_help },
    { name = "Decompile", action = M.decompile },
    { name = "Organize Imports", action = M.organize_imports },
    { name = "Export Workspace", action = M.export_workspace },
    { name = "Apply Fix", action = M.apply_fix },
    { name = "Clear Decompile Cache", action = M.clear_decompile_cache },
    { name = "Run Nearest Test", action = M.test_nearest },
    { name = "Run File Tests", action = M.test_file },
    { name = "Run All Tests", action = M.test_all },
    { name = "Code Actions", action = M.code_actions },
    { name = "Refactor Menu", action = M.refactor },
    { name = "Extract Variable", action = M.extract_variable },
    { name = "Inline Variable", action = M.inline_variable },
  }
end

return M
