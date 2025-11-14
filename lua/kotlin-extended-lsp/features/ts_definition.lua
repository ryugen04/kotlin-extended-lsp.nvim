-- Treesitterベースの定義ジャンプ機能
-- nvim-treesitter-refactorのアプローチを参考にした実装
-- ファイル内のローカル定義を高速に解決し、見つからない場合はLSPにフォールバック

local ts_utils = require('kotlin-extended-lsp.ts_utils')
local utils = require('kotlin-extended-lsp.utils')
local M = {}

-- treesitterで定義を検索し、見つからなければLSPにフォールバック
-- decompile機能と統合してJAR内ファイルにも対応
function M.goto_definition()
  local bufnr = vim.api.nvim_get_current_buf()

  -- treesitterが利用可能かチェック
  if not ts_utils.is_treesitter_available() then
    -- decompile機能を使った定義ジャンプ（JAR対応）
    local decompile = require('kotlin-extended-lsp.features.decompile')
    decompile.go_to_definition()
    return
  end

  -- カーソル位置のノードを取得
  local node = ts_utils.get_node_at_cursor(bufnr)
  if not node then
    -- decompile機能を使った定義ジャンプ（JAR対応）
    local decompile = require('kotlin-extended-lsp.features.decompile')
    decompile.go_to_definition()
    return
  end

  -- treesitterで定義を検索
  local definition = ts_utils.find_definition(node, bufnr)

  if definition and definition ~= node then
    -- 定義が見つかった場合はジャンプ
    local ok = pcall(ts_utils.goto_node, definition, bufnr)
    if ok then
      return
    end
  end

  -- 見つからない場合はLSPにフォールバック（JAR対応版）
  local decompile = require('kotlin-extended-lsp.features.decompile')
  decompile.go_to_definition()
end

-- treesitterで型定義を検索し、見つからなければLSPにフォールバック
function M.goto_type_definition()
  local bufnr = vim.api.nvim_get_current_buf()

  -- treesitterが利用可能かチェック
  if not ts_utils.is_treesitter_available() then
    -- 静かにLSPベースの実装にフォールバック
    local type_def = require('kotlin-extended-lsp.features.type_definition')
    type_def.go_to_type_definition()
    return
  end

  -- カーソル位置の型アノテーションを取得
  local ok, type_name, type_node = pcall(ts_utils.get_type_annotation_at_cursor, bufnr)

  if not ok or not type_name then
    -- 型抽出に失敗した場合は静かにLSPベースの実装にフォールバック
    local type_def = require('kotlin-extended-lsp.features.type_definition')
    type_def.go_to_type_definition()
    return
  end

  -- Nullable型の ? を除去
  type_name = type_name:gsub('%?$', '')

  -- ジェネリクスの外側の型を抽出
  type_name = type_name:match('^([^<]+)')

  -- 現在のファイル内で型定義を検索
  local ok_search, definitions = pcall(ts_utils.find_type_definition_in_file, type_name, bufnr)

  if not ok_search or not definitions or #definitions == 0 then
    -- 検索に失敗またはファイル内に見つからない場合はLSPベースの実装にフォールバック
    local type_def = require('kotlin-extended-lsp.features.type_definition')
    type_def.go_to_type_definition()
    return
  end

  if #definitions == 1 then
    -- 単一の定義が見つかった場合はジャンプ
    local ok_goto = pcall(ts_utils.goto_node, definitions[1], bufnr)
    if ok_goto then
      return
    end
    -- ジャンプに失敗した場合はLSPフォールバック
    local type_def = require('kotlin-extended-lsp.features.type_definition')
    type_def.go_to_type_definition()
    return
  elseif #definitions > 1 then
    -- 複数の定義が見つかった場合は選択UI
    vim.ui.select(definitions, {
      prompt = 'Select type definition:',
      format_item = function(node)
        local start_row, start_col = node:start()
        return string.format('Line %d, Col %d', start_row + 1, start_col + 1)
      end
    }, function(selected)
      if selected then
        pcall(ts_utils.goto_node, selected, bufnr)
      end
    end)
    return
  end
end

-- 実装ジャンプ（treesitterでは困難なのでLSPのみ使用）
function M.goto_implementation()
  local impl = require('kotlin-extended-lsp.features.implementation')
  impl.go_to_implementation()
end

-- 宣言ジャンプ（treesitterでは意味がないのでLSPのみ使用）
function M.goto_declaration()
  local decl = require('kotlin-extended-lsp.features.declaration')
  decl.go_to_declaration()
end

-- setup: treesitterベースのジャンプ機能を有効化
function M.setup(opts)
  opts = opts or {}

  -- コマンドを作成（オプション）
  if opts.create_commands then
    vim.api.nvim_create_user_command('KotlinTsGoToDefinition', function()
      M.goto_definition()
    end, {
      desc = 'Go to definition (treesitter + LSP fallback)'
    })

    vim.api.nvim_create_user_command('KotlinTsGoToTypeDefinition', function()
      M.goto_type_definition()
    end, {
      desc = 'Go to type definition (treesitter + LSP fallback)'
    })
  end

  -- キーマップ設定（デフォルトではgdとgyを上書き）
  if opts.setup_keymaps ~= false then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspTsDefinition', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf
          local keymap_opts = { buffer = bufnr, silent = true }

          -- gd: treesitterベースの定義ジャンプ（LSPフォールバック）
          if opts.override_gd ~= false then
            vim.keymap.set('n', 'gd', M.goto_definition,
              vim.tbl_extend('force', keymap_opts, {
                desc = 'Go to definition (TS+LSP)'
              }))
          end

          -- gy: treesitterベースの型定義ジャンプ（LSPフォールバック）
          if opts.override_gy ~= false then
            vim.keymap.set('n', 'gy', M.goto_type_definition,
              vim.tbl_extend('force', keymap_opts, {
                desc = 'Go to type definition (TS+LSP)'
              }))
          end
        end
      end
    })
  end
end

return M
