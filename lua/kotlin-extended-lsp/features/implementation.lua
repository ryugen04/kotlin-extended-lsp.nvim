-- 実装ジャンプ機能（高度なアルゴリズム版）
-- kotlin-lspがtextDocument/implementationをサポートしていないため、
-- 複数の戦略を組み合わせた代替実装を提供

local utils = require('kotlin-extended-lsp.utils')
local ts_utils = require('kotlin-extended-lsp.ts_utils')
local M = {}

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

-- 戦略1: References + Hover で実装を探す
local function find_via_references(client, symbol_name, callback)
  local params = vim.lsp.util.make_position_params()

  client.request('textDocument/references', params, function(err, references)
    if err or not references or #references == 0 then
      callback(nil)
      return
    end

    log(string.format('Found %d references', #references))

    -- 各参照の型情報を取得
    local implementations = {}
    local pending = #references

    for _, ref in ipairs(references) do
      -- 参照位置でhoverを実行して型情報を取得
      local hover_params = {
        textDocument = { uri = ref.uri },
        position = ref.range.start
      }

      client.request('textDocument/hover', hover_params, function(hover_err, hover_result)
        vim.schedule(function()
          if hover_result and hover_result.contents then
            local contents = hover_result.contents
            local value = type(contents) == 'table' and contents.value or contents

            -- 型情報から実装クラスを抽出
            -- 例: "val user: UserImpl" から "UserImpl" を抽出
            if type(value) == 'string' then
              local impl_type = value:match(':([^:]+)$')
              if impl_type then
                impl_type = impl_type:match('^%s*(.-)%s*$') -- trim

                -- 元のシンボル名と異なる型を見つけた
                if not impl_type:match('^' .. symbol_name .. '$') then
                  table.insert(implementations, {
                    name = impl_type,
                    location = ref,
                    source = 'reference_hover'
                  })
                  log('Found implementation via reference: ' .. impl_type)
                end
              end
            end
          end

          pending = pending - 1
          if pending == 0 then
            callback(implementations)
          end
        end)
      end)
    end
  end)
end

-- 戦略2: DocumentSymbol + containerNameでメンバーを探す
local function find_via_document_symbols(client, symbol_name, callback)
  local params = { textDocument = vim.lsp.util.make_text_document_params() }

  client.request('textDocument/documentSymbol', params, function(err, symbols)
    if err or not symbols then
      callback(nil)
      return
    end

    local implementations = {}

    -- 再帰的にシンボルを探索
    local function search_symbols(syms, container)
      for _, sym in ipairs(syms) do
        -- メソッドや関数を探す
        if sym.kind == vim.lsp.protocol.SymbolKind.Method or
           sym.kind == vim.lsp.protocol.SymbolKind.Function then

          -- 名前が一致する場合
          if sym.name == symbol_name then
            table.insert(implementations, {
              name = sym.name,
              container = container or sym.containerName,
              location = sym.location or { uri = params.textDocument.uri, range = sym.range },
              kind = vim.lsp.protocol.SymbolKind[sym.kind],
              source = 'document_symbol'
            })
            log('Found method: ' .. sym.name .. ' in ' .. (container or 'unknown'))
          end
        end

        -- 子シンボルを探索
        if sym.children then
          search_symbols(sym.children, sym.name)
        end
      end
    end

    search_symbols(symbols)
    callback(implementations)
  end)
end

-- 戦略3: Workspace Symbol で広範囲検索
local function find_via_workspace_symbol(client, symbol_name, def_uri, callback)
  local symbol_params = { query = symbol_name }

  client.request('workspace/symbol', symbol_params, function(err, symbols)
    if err or not symbols or #symbols == 0 then
      callback(nil)
      return
    end

    log(string.format('workspace/symbol found %d symbols', #symbols))

    local implementations = {}

    for _, symbol in ipairs(symbols) do
      if symbol.location then
        local is_different_file = symbol.location.uri ~= def_uri

        -- より広範な種類を受け入れる
        local valid_kinds = {
          [vim.lsp.protocol.SymbolKind.Class] = true,
          [vim.lsp.protocol.SymbolKind.Interface] = true,
          [vim.lsp.protocol.SymbolKind.Object] = true,
          [vim.lsp.protocol.SymbolKind.Method] = true,
          [vim.lsp.protocol.SymbolKind.Function] = true,
        }

        if valid_kinds[symbol.kind] then
          -- 完全一致または部分一致（接尾辞Impl, 接頭辞など）
          local name_matches = symbol.name == symbol_name or
                               symbol.name:match(symbol_name .. 'Impl$') or
                               symbol.name:match('^' .. symbol_name .. 'Impl') or
                               symbol.name:match(symbol_name)

          if name_matches or is_different_file then
            table.insert(implementations, {
              name = symbol.name,
              container = symbol.containerName,
              location = symbol.location,
              kind = vim.lsp.protocol.SymbolKind[symbol.kind],
              source = 'workspace_symbol',
              score = name_matches and 10 or 1  -- スコアリング
            })
            log('Found symbol: ' .. symbol.name .. ' [' .. (symbol.containerName or ''))
          end
        end
      end
    end

    callback(implementations)
  end)
end

-- 戦略4: Grep fallback（LSPが失敗した場合）
local function find_via_grep(symbol_name, callback)
  -- workspace内でシンボル名をgrepで検索
  vim.fn.jobstart({'rg', '--json', symbol_name, vim.fn.getcwd()}, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local implementations = {}

      for _, line in ipairs(data) do
        if line ~= '' then
          local ok, decoded = pcall(vim.json.decode, line)
          if ok and decoded.type == 'match' then
            local file = decoded.data.path.text
            local line_num = decoded.data.line_number

            table.insert(implementations, {
              name = symbol_name,
              file = file,
              line = line_num,
              source = 'grep_fallback'
            })
          end
        end
      end

      callback(implementations)
    end
  })
end

-- 実装をスコアリングして優先順位付け
local function score_and_sort(implementations, symbol_name, context)
  for _, impl in ipairs(implementations) do
    impl.score = impl.score or 0

    -- 名前の完全一致
    if impl.name == symbol_name then
      impl.score = impl.score + 50
    end

    -- Impl接尾辞
    if impl.name:match('Impl$') then
      impl.score = impl.score + 30
    end

    -- 関数コンテキストでMethod/Functionならボーナス
    if context.is_function_call and
       (impl.kind == 'Method' or impl.kind == 'Function') then
      impl.score = impl.score + 40
    end

    -- クラスコンテキストでClassならボーナス
    if context.is_class_reference and impl.kind == 'Class' then
      impl.score = impl.score + 40
    end

    -- ソース別のボーナス
    if impl.source == 'reference_hover' then
      impl.score = impl.score + 35  -- 最も信頼性が高い
    elseif impl.source == 'document_symbol' then
      impl.score = impl.score + 25
    elseif impl.source == 'workspace_symbol' then
      impl.score = impl.score + 15
    end
  end

  -- スコアでソート
  table.sort(implementations, function(a, b)
    return a.score > b.score
  end)

  return implementations
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

      -- 複数の戦略を並列実行
      local all_implementations = {}
      local strategies_completed = 0
      local total_strategies = 3

      local function collect_results(results)
        strategies_completed = strategies_completed + 1

        if results and #results > 0 then
          for _, impl in ipairs(results) do
            table.insert(all_implementations, impl)
          end
        end

        -- 全戦略完了後に結果を表示
        if strategies_completed >= total_strategies then
          vim.schedule(function()
            if #all_implementations == 0 then
              vim.notify('No implementations found for: ' .. context.word, vim.log.levels.WARN)
              return
            end

            -- 重複除去
            local seen = {}
            local unique = {}
            for _, impl in ipairs(all_implementations) do
              local key = (impl.location and impl.location.uri or '') .. ':' .. impl.name
              if not seen[key] then
                seen[key] = true
                table.insert(unique, impl)
              end
            end

            -- スコアリングとソート
            unique = score_and_sort(unique, context.word, context)

            log(string.format('Found %d unique implementations', #unique))

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
        end
      end

      -- 戦略1: References + Hover
      find_via_references(client, context.word, collect_results)

      -- 戦略2: Document Symbol
      find_via_document_symbols(client, context.word, collect_results)

      -- 戦略3: Workspace Symbol
      find_via_workspace_symbol(client, context.word, def_uri, collect_results)
    end)
  end)
end

-- setup: コマンドとキーマップを設定
function M.setup(opts)
  opts = opts or {}

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
