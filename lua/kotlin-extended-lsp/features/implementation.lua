-- 実装ジャンプ機能（高度なアルゴリズム版）
-- kotlin-lspがtextDocument/implementationをサポートしていないため、
-- 複数の戦略を組み合わせた代替実装を提供

local utils = require('kotlin-extended-lsp.utils')
local ts_utils = require('kotlin-extended-lsp.ts_utils')
local M = {}

local config = {
  use_telescope = true,
}

local ignore_path_patterns = {
  '/build/',
  '/.gradle/',
  '/.idea/',
  '/out/',
  '/generated/',
  '/dist/',
}

local function path_is_ignored(path)
  if not path then
    return false
  end
  for _, pattern in ipairs(ignore_path_patterns) do
    if path:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

local function read_file_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return lines
end

local function read_file_text(path)
  local lines = read_file_lines(path)
  if not lines then
    return nil
  end
  return table.concat(lines, '\n')
end

local function extract_package(lines)
  if not lines then
    return nil
  end
  for i = 1, math.min(#lines, 50) do
    local line = lines[i]
    local pkg = line:match('^%s*package%s+([%w_%.]+)')
    if pkg then
      return pkg
    end
  end
  return nil
end

local function match_target_name(text, target_name, target_qualified)
  if not text then
    return false
  end
  local escaped = vim.pesc(target_name)
  if text:match('%f[%w_]' .. escaped .. '%f[^%w_]') then
    return true
  end
  if target_qualified then
    local escaped_qualified = vim.pesc(target_qualified)
    if text:match('%f[%w_]' .. escaped_qualified .. '%f[^%w_]') then
      return true
    end
  end
  return false
end

local function matches_inheritance_treesitter(path, class_name, target_name, target_qualified)
  if not path or path == '' then
    return false
  end

  if not path:match('%.kt$') and not path:match('%.kts$') then
    return false
  end

  local text = read_file_text(path)
  if not text then
    return false
  end

  local ok, parser = pcall(vim.treesitter.get_string_parser, text, 'kotlin')
  if not ok or not parser then
    return false
  end

  local tree = parser:parse()[1]
  if not tree then
    return false
  end

  local root = tree:root()
  local found = false

  local function inspect_class(node)
    local name_node = nil
    local delegation = nil
    for child in node:iter_children() do
      local ctype = child:type()
      if ctype == 'simple_identifier' then
        name_node = child
      elseif ctype == 'delegation_specifiers' then
        delegation = child
      end
    end

    if not name_node then
      return
    end

    local name_text = vim.treesitter.get_node_text(name_node, text)
    if name_text ~= class_name then
      return
    end

    local delegation_text = delegation and vim.treesitter.get_node_text(delegation, text) or ''
    if match_target_name(delegation_text, target_name, target_qualified) then
      found = true
    end
  end

  local function walk(node)
    if found then
      return
    end
    local ntype = node:type()
    if ntype == 'class_declaration' or ntype == 'object_declaration' then
      inspect_class(node)
    end
    for child in node:iter_children() do
      walk(child)
      if found then
        return
      end
    end
  end

  walk(root)
  return found
end

local function matches_method_implementation_treesitter(path, method_name, target_name, target_qualified)
  if not path or path == '' then
    return false
  end

  if not path:match('%.kt$') and not path:match('%.kts$') then
    return false
  end

  local text = read_file_text(path)
  if not text then
    return false
  end

  local ok, parser = pcall(vim.treesitter.get_string_parser, text, 'kotlin')
  if not ok or not parser then
    return false
  end

  local tree = parser:parse()[1]
  if not tree then
    return false
  end

  local root = tree:root()
  local found = false

  local function class_implements_target(node)
    for child in node:iter_children() do
      if child:type() == 'delegation_specifiers' then
        local delegation_text = vim.treesitter.get_node_text(child, text)
        if match_target_name(delegation_text, target_name, target_qualified) then
          return true
        end
      end
    end
    return false
  end

  local function class_has_method(node)
    for child in node:iter_children() do
      if child:type() == 'class_body' then
        for body_child in child:iter_children() do
          if body_child:type() == 'function_declaration' then
            for fn_child in body_child:iter_children() do
              if fn_child:type() == 'simple_identifier' then
                local name_text = vim.treesitter.get_node_text(fn_child, text)
                if name_text == method_name then
                  return true
                end
              end
            end
          end
        end
      end
    end
    return false
  end

  local function walk(node)
    if found then
      return
    end
    local ntype = node:type()
    if ntype == 'class_declaration' or ntype == 'object_declaration' then
      if class_implements_target(node) and class_has_method(node) then
        found = true
        return
      end
    end
    for child in node:iter_children() do
      walk(child)
      if found then
        return
      end
    end
  end

  walk(root)
  return found
end

local function line_contains_target(line, target_name, target_qualified)
  if not line then
    return false
  end
  if not line:find(':', 1, true) then
    return false
  end
  return match_target_name(line, target_name, target_qualified)
end

local function matches_inheritance(lines, start_line, target_name, target_qualified)
  if not lines or not start_line then
    return false
  end
  local first = math.max(start_line + 1, 1)
  local last = math.min(first + 6, #lines)
  for i = first, last do
    if line_contains_target(lines[i], target_name, target_qualified) then
      return true
    end
  end
  return false
end

local function enrich_candidates(candidates, target_name, target_qualified, target_package)
  local enriched = {}
  for _, impl in ipairs(candidates) do
    if impl.location and impl.location.uri then
      local path = vim.uri_to_fname(impl.location.uri)
      if not path_is_ignored(path) then
        local lines = read_file_lines(path)
        local package_name = extract_package(lines)
        local start_line = impl.location.range and impl.location.range.start
          and impl.location.range.start.line or 0
        local ts_match = false
        if impl.kind == 'Method' or impl.kind == 'Function' then
          ts_match = matches_method_implementation_treesitter(
            path,
            impl.name,
            target_name,
            target_qualified
          )
        else
          ts_match = matches_inheritance_treesitter(
            path,
            impl.name,
            target_name,
            target_qualified
          )
        end

        impl._path = path
        impl._package = package_name
        impl._same_package = target_package and package_name == target_package or false
        impl._inheritance_match = ts_match or matches_inheritance(
          lines,
          start_line,
          target_name,
          target_qualified
        )
        impl._is_test = path:find('/test/', 1, true) ~= nil

        table.insert(enriched, impl)
      end
    end
  end
  return enriched
end

local function rank_and_filter(candidates, target_name, target_package)
  for _, impl in ipairs(candidates) do
    local score = 0
    if impl._inheritance_match then
      score = score + 100
    end
    if impl._same_package then
      score = score + 15
    end
    if impl.name == target_name then
      score = score + 20
    end
    if impl.name:match('Impl$') then
      score = score + 10
    end
    if impl._is_test then
      score = score - 10
    end
    if impl.kind == 'Class' or impl.kind == 'Object' then
      score = score + 5
    end
    impl.score = score
  end

  table.sort(candidates, function(a, b)
    return a.score > b.score
  end)

  return candidates
end

-- デバッグログ
local function log(msg, level)
  if vim.g.kotlin_lsp_debug then
    vim.notify('[Implementation] ' .. msg, level or vim.log.levels.DEBUG)
  end
end

-- カーソル位置のシンボル情報を取得
local function get_symbol_info()
  local bufnr = vim.api.nvim_get_current_buf()
  local word = vim.fn.expand('<cword>')

  -- Treesitterでコンテキストを取得
  local context = {
    word = word,
    is_function_call = false,
    is_class_reference = false,
    is_interface = false,
    parent_class = nil,
  }

  if ts_utils.is_treesitter_available() then
    local node = ts_utils.get_node_at_cursor(bufnr)
    if node then
      -- 親ノードを遡ってコンテキストを判定
      local parent = node:parent()
      while parent do
        local node_type = parent:type()

        -- 関数呼び出し
        if node_type == 'call_expression' then
          context.is_function_call = true
          log('Detected function call context')
        end

        -- クラス宣言
        if node_type == 'class_declaration' then
          context.is_class_reference = true
          -- スーパークラス情報を取得
          for child in parent:iter_children() do
            if child:type() == 'delegation_specifiers' then
              context.parent_class = vim.treesitter.get_node_text(child, bufnr)
              log('Found parent class: ' .. context.parent_class)
            end
          end
        end

        -- インターフェース宣言
        if node_type == 'class_declaration' then
          for child in parent:iter_children() do
            if child:type() == 'modifiers' then
              local mods = vim.treesitter.get_node_text(child, bufnr)
              if mods:match('interface') then
                context.is_interface = true
                log('Detected interface')
              end
            end
          end
        end

        parent = parent:parent()
      end
    end
  end

  return context
end

-- Workspace Symbol で広範囲検索（クラス実装寄りに絞る）
local function find_via_workspace_symbol(client, symbol_name, def_uri, context, callback)
  local queries = { symbol_name, symbol_name .. 'Impl' }
  if context and context.is_function_call then
    queries = { symbol_name }
  end
  local pending = #queries
  local collected = {}

  local function handle_symbols(symbols)
    if symbols then
      for _, symbol in ipairs(symbols) do
        if symbol.location then
          local valid_kinds
          if context and context.is_function_call then
            valid_kinds = {
              [vim.lsp.protocol.SymbolKind.Method] = true,
              [vim.lsp.protocol.SymbolKind.Function] = true,
            }
          else
            valid_kinds = {
              [vim.lsp.protocol.SymbolKind.Class] = true,
              [vim.lsp.protocol.SymbolKind.Object] = true,
            }
          end

          if valid_kinds[symbol.kind] then
            table.insert(collected, {
              name = symbol.name,
              container = symbol.containerName,
              location = symbol.location,
              kind = vim.lsp.protocol.SymbolKind[symbol.kind],
              source = 'workspace_symbol',
            })
          end
        end
      end
    end

    pending = pending - 1
    if pending == 0 then
      callback(collected)
    end
  end

  for _, query in ipairs(queries) do
    client.request('workspace/symbol', { query = query }, function(err, symbols)
      if err or not symbols or #symbols == 0 then
        handle_symbols(nil)
        return
      end
      log(string.format('workspace/symbol[%s] found %d symbols', query, #symbols))
      handle_symbols(symbols)
    end)
  end
end

local function get_package_from_uri(uri)
  if not uri then
    return nil
  end
  local path = vim.uri_to_fname(uri)
  if not path then
    return nil
  end
  local lines = read_file_lines(path)
  return extract_package(lines)
end

-- メイン実装ジャンプ関数
function M.go_to_implementation()
  local client, err = utils.get_kotlin_lsp_client()
  if not client then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- サーバーが標準メソッドをサポートしている場合は標準を使用
  if client.supports_method('textDocument/implementation') then
    if config.use_telescope then
      local ok, builtin = pcall(require, 'telescope.builtin')
      if ok then
        builtin.lsp_implementations()
        return
      end
    end
    vim.lsp.buf.implementation()
    return
  end

  -- シンボル情報とコンテキストを取得
  local context = get_symbol_info()

  if not context.word or context.word == '' then
    vim.notify('No symbol found at cursor', vim.log.levels.WARN)
    return
  end

  vim.notify('Searching for implementations of: ' .. context.word, vim.log.levels.INFO)

  -- 定義を取得（URIの特定のため）
  local params = vim.lsp.util.make_position_params()

  client.request('textDocument/definition', params, function(err, result)
    vim.schedule(function()
      local def_uri = nil
      if result and not vim.tbl_isempty(result) then
        def_uri = type(result) == 'table' and (result[1] or result).uri or result.uri
        log('Definition URI: ' .. def_uri)
      end

  local target_package = get_package_from_uri(def_uri)

  find_via_workspace_symbol(client, context.word, def_uri, context, function(results)
    vim.schedule(function()
      if not results or #results == 0 then
        vim.notify('No implementations found for: ' .. context.word, vim.log.levels.WARN)
        return
      end

      -- 重複除去
      local seen = {}
      local unique = {}
      for _, impl in ipairs(results) do
        local key = (impl.location and impl.location.uri or '') .. ':' .. impl.name
        if not seen[key] then
          seen[key] = true
          table.insert(unique, impl)
        end
      end

      local target_qualified = target_package and (target_package .. '.' .. context.word) or nil
      unique = enrich_candidates(unique, context.word, target_qualified, target_package)
      unique = rank_and_filter(unique, context.word, target_package)

      log(string.format('Found %d unique implementations', #unique))

      if #unique == 0 then
        vim.notify('No implementations found for: ' .. context.word, vim.log.levels.WARN)
        return
      end

      -- 1つの実装のみの場合は直接ジャンプ
      if #unique == 1 then
        local impl = unique[1]
        if impl.location then
          vim.lsp.util.jump_to_location(impl.location, 'utf-8')
          vim.notify('Jumped to implementation: ' .. impl.name, vim.log.levels.INFO)
        end
        return
      end

      -- 複数の実装がある場合は選択UI
      if config.use_telescope then
        local ok, pickers = pcall(require, 'telescope.pickers')
        if ok then
          local finders = require('telescope.finders')
          local conf = require('telescope.config').values
          local actions = require('telescope.actions')
          local action_state = require('telescope.actions.state')

          pickers.new({}, {
            prompt_title = 'Implementations (' .. #unique .. ')',
            finder = finders.new_table({
              results = unique,
              entry_maker = function(impl)
                local container = impl.container and (' in ' .. impl.container) or ''
                local kind = impl.kind and (' [' .. impl.kind .. ']') or ''
                local score_str = ' (score: ' .. (impl.score or 0) .. ')'
                return {
                  value = impl,
                  display = string.format('%s%s%s%s', impl.name, container, kind, score_str),
                  ordinal = impl.name .. (impl.container or ''),
                }
              end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, _)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection and selection.value and selection.value.location then
                  vim.lsp.util.jump_to_location(selection.value.location, 'utf-8')
                  vim.notify('Jumped to implementation: ' .. selection.value.name, vim.log.levels.INFO)
                end
              end)
              return true
            end,
          }):find()
          return
        end
      end

      vim.ui.select(unique, {
        prompt = 'Select implementation (' .. #unique .. ' found):',
        format_item = function(impl)
          local container = impl.container and (' in ' .. impl.container) or ''
          local kind = impl.kind and (' [' .. impl.kind .. ']') or ''
          local score_str = ' (score: ' .. (impl.score or 0) .. ')'
          return string.format('%s%s%s%s', impl.name, container, kind, score_str)
        end,
      }, function(selected)
        if selected and selected.location then
          vim.lsp.util.jump_to_location(selected.location, 'utf-8')
          vim.notify('Jumped to implementation: ' .. selected.name, vim.log.levels.INFO)
        end
      end)
    end)
  end)
    end)
  end)
end

-- setup: コマンドとキーマップを設定
function M.setup(opts)
  opts = opts or {}
  if opts.use_telescope ~= nil then
    config.use_telescope = opts.use_telescope
  end

  -- コマンドを作成
  vim.api.nvim_create_user_command('KotlinGoToImplementation', function()
    M.go_to_implementation()
  end, {
    desc = 'Go to implementation (advanced algorithm)'
  })

  -- キーマップ設定（オプション）
  if opts.setup_keymaps ~= false then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('KotlinExtendedLspImplementation', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'kotlin-lsp' then
          local bufnr = args.buf
          local keymap_opts = { buffer = bufnr, silent = true }

          -- gi: 実装へジャンプ（高度なアルゴリズム版）
          vim.keymap.set('n', 'gi', M.go_to_implementation,
            vim.tbl_extend('force', keymap_opts, {
              desc = 'Go to implementation (advanced)'
            }))
        end
      end
    })
  end

  -- デバッグモードの設定
  vim.g.kotlin_lsp_debug = opts.debug or false
end

return M
