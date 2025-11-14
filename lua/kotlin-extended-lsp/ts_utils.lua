-- Treesitterユーティリティ関数
-- nvim-treesitter-refactorの実装を参考にした独自実装

local M = {}

-- treesitterが利用可能かチェック
function M.is_treesitter_available()
  local ok = pcall(require, 'nvim-treesitter')
  if not ok then
    return false
  end

  -- Kotlinパーサーがインストールされているか確認
  local has_kotlin = vim.treesitter.language.get_lang('kotlin')
  return has_kotlin ~= nil
end

-- カーソル位置のTreesitterノードを取得
function M.get_node_at_cursor(bufnr, winnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  winnr = winnr or vim.api.nvim_get_current_win()

  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local row = cursor[1] - 1  -- 0-indexed
  local col = cursor[2]

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'kotlin')
  if not ok or not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local root = tree:root()
  return root:named_descendant_for_range(row, col, row, col)
end

-- ノードのテキストを取得
function M.get_node_text(node, bufnr)
  if not node then
    return nil
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.treesitter.get_node_text(node, bufnr)
end

-- ノードの位置へジャンプ
function M.goto_node(node, bufnr)
  if not node then
    return false
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local start_row, start_col = node:start()

  -- バッファが現在のバッファと異なる場合は切り替え
  if bufnr ~= vim.api.nvim_get_current_buf() then
    vim.api.nvim_set_current_buf(bufnr)
  end

  -- カーソルを移動（1-indexed）
  vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })

  -- 画面の中央に表示
  vim.cmd('normal! zz')

  return true
end

-- 親スコープを取得（スコープツリーを上方向に走査）
function M.get_parent_scope(node, bufnr)
  if not node then
    return nil
  end

  local parent = node:parent()
  while parent do
    -- @local.scopeとマッチするノードタイプかチェック
    local type = parent:type()
    local scope_types = {
      'if_expression',
      'when_expression',
      'when_entry',
      'for_statement',
      'while_statement',
      'do_while_statement',
      'lambda_literal',
      'function_declaration',
      'primary_constructor',
      'secondary_constructor',
      'anonymous_initializer',
      'class_declaration',
      'enum_class_body',
      'enum_entry',
      'interpolated_expression',
    }

    for _, scope_type in ipairs(scope_types) do
      if type == scope_type then
        return parent
      end
    end

    parent = parent:parent()
  end

  return nil
end

-- スコープのイテレータ（現在のノードから親方向にスコープを列挙）
function M.iter_scope_tree(node, bufnr)
  local current_scope = M.get_parent_scope(node, bufnr)

  return function()
    if not current_scope then
      return nil
    end

    local scope = current_scope
    current_scope = M.get_parent_scope(current_scope:parent(), bufnr)
    return scope
  end
end

-- 定義ノードを検索するためのルックアップテーブルを構築
function M.get_definitions_lookup_table(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'kotlin')
  if not ok or not parser then
    return {}
  end

  local tree = parser:parse()[1]
  if not tree then
    return {}
  end

  local root = tree:root()
  local lookup = {}

  -- locals.scmのクエリを使用して定義を抽出
  local query = vim.treesitter.query.get('kotlin', 'locals')
  if not query then
    return {}
  end

  for id, node, metadata in query:iter_captures(root, bufnr) do
    local capture_name = query.captures[id]

    -- @local.definition.* のキャプチャのみ処理
    if capture_name and capture_name:match('^local%.definition%.') then
      local node_text = vim.treesitter.get_node_text(node, bufnr)

      -- スコープ情報を取得
      local scope = M.get_parent_scope(node, bufnr)
      if scope then
        local scope_start, _, scope_end, _ = scope:range()

        -- 一意のIDを生成（ノードテキスト + スコープ範囲）
        local id_key = string.format('%s:%d:%d', node_text, scope_start, scope_end)
        lookup[id_key] = node
      else
        -- スコープがない場合はグローバル扱い
        lookup[node_text] = node
      end
    end
  end

  return lookup
end

-- カーソル位置のシンボルの定義を検索
function M.find_definition(node, bufnr)
  if not node then
    return nil
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- simple_identifierノードでなければ親を探索
  while node and node:type() ~= 'simple_identifier' do
    node = node:parent()
  end

  if not node or node:type() ~= 'simple_identifier' then
    return nil
  end

  local def_lookup = M.get_definitions_lookup_table(bufnr)
  local node_text = vim.treesitter.get_node_text(node, bufnr)

  -- スコープツリーを上方に走査しながら定義を検索
  for scope in M.iter_scope_tree(node, bufnr) do
    local scope_start, _, scope_end, _ = scope:range()
    local id = string.format('%s:%d:%d', node_text, scope_start, scope_end)

    if def_lookup[id] then
      return def_lookup[id]
    end
  end

  -- スコープに見つからない場合はグローバルを検索
  if def_lookup[node_text] then
    return def_lookup[node_text]
  end

  return nil
end

-- 型定義ノード（class, interface, type alias）を検索
function M.find_type_definition_in_file(type_name, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'kotlin')
  if not ok or not parser then
    return {}
  end

  local tree = parser:parse()[1]
  if not tree then
    return {}
  end

  local root = tree:root()
  local results = {}

  -- 型定義を検索するクエリ
  local query_string = string.format([[
    (class_declaration
      (type_identifier) @type_name
      (#eq? @type_name "%s")) @class_def

    (type_alias
      (type_identifier) @type_name
      (#eq? @type_name "%s")) @type_def
  ]], type_name, type_name)

  local ok_query, query = pcall(vim.treesitter.query.parse, 'kotlin', query_string)
  if not ok_query or not query then
    return {}
  end

  for id, node in query:iter_captures(root, bufnr) do
    local capture_name = query.captures[id]
    if capture_name == 'class_def' or capture_name == 'type_def' then
      table.insert(results, node)
    end
  end

  return results
end

-- カーソル位置の型アノテーションを抽出
function M.get_type_annotation_at_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local node = M.get_node_at_cursor(bufnr)
  if not node then
    return nil
  end

  -- 型アノテーションを探すために親ノードを走査
  local current = node
  while current do
    local type_node = M.extract_type_from_node(current, bufnr)
    if type_node then
      return type_node
    end
    current = current:parent()
  end

  return nil
end

-- ノードから型情報を抽出
function M.extract_type_from_node(node, bufnr)
  if not node then
    return nil
  end

  local node_type = node:type()

  -- property_declaration (val x: Type)
  if node_type == 'property_declaration' then
    for child in node:iter_children() do
      if child:type() == 'variable_declaration' then
        for var_child in child:iter_children() do
          if var_child:type() == 'user_type' or var_child:type() == 'type_reference' then
            return M.get_type_identifier_from_type_node(var_child, bufnr)
          end
        end
      end
    end
  end

  -- function_declaration (fun foo(): Type)
  if node_type == 'function_declaration' then
    for child in node:iter_children() do
      if child:type() == 'user_type' or child:type() == 'type_reference' then
        return M.get_type_identifier_from_type_node(child, bufnr)
      end
    end
  end

  -- parameter (param: Type)
  if node_type == 'parameter' then
    for child in node:iter_children() do
      if child:type() == 'user_type' or child:type() == 'type_reference' then
        return M.get_type_identifier_from_type_node(child, bufnr)
      end
    end
  end

  return nil
end

-- type_nodeから実際の型名（type_identifier）を取得
function M.get_type_identifier_from_type_node(type_node, bufnr)
  if not type_node then
    return nil
  end

  -- user_type や type_reference の子ノードから type_identifier を探す
  for child in type_node:iter_children() do
    if child:type() == 'type_identifier' then
      local type_name = vim.treesitter.get_node_text(child, bufnr)
      return type_name, child
    end

    -- ネストしている場合（例: List<User>の User部分）
    if child:type() == 'user_type' or child:type() == 'type_arguments' then
      local nested_type = M.get_type_identifier_from_type_node(child, bufnr)
      if nested_type then
        return nested_type
      end
    end
  end

  -- 直接type_identifierの場合
  if type_node:type() == 'type_identifier' then
    return vim.treesitter.get_node_text(type_node, bufnr), type_node
  end

  return nil
end

return M
