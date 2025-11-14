# デコンパイル機能の厳格なコードレビュー

## 重大な問題（Critical Issues）

### 1. utils.lua:66-68 - 非推奨APIの使用

```lua
vim.api.nvim_buf_set_option(buf, 'modifiable', false)
vim.api.nvim_buf_set_option(buf, 'readonly', true)
vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
```

**問題**: `nvim_buf_set_option` はNeovim 0.10で**非推奨**になり、将来削除される予定。

**影響**: Neovim 0.11以降で動作しなくなる可能性。

**修正**: `vim.bo[buf]` または `vim.api.nvim_set_option_value` を使用すべき。

```lua
-- 正しい実装
vim.bo[buf].modifiable = false
vim.bo[buf].readonly = true
vim.bo[buf].buftype = 'nofile'
vim.bo[buf].filetype = filetype or ''
```

---

### 2. decompile.lua:59-78 - コールバック内での同期的UI操作

```lua
utils.execute_command('decompile', { uri }, function(result)
  -- ...
  local buf = utils.create_readonly_buffer(buffer_name, result.content, 'kotlin')
  decompiled_buffers[uri] = buf
  utils.open_buffer_in_split(buf, split_type)  -- UI操作
  vim.notify('Decompilation completed: ' .. class_name, vim.log.levels.INFO)
end)
```

**問題**: LSPコールバックはメインスレッド外で実行される可能性があり、UI操作（バッファ作成、ウィンドウ分割）を直接実行するのは危険。

**影響**: ランダムにクラッシュする、UI操作が失敗する可能性。

**修正**: `vim.schedule` でメインスレッドにディスパッチすべき。

```lua
utils.execute_command('decompile', { uri }, function(result)
  vim.schedule(function()
    if not result or not result.content then
      vim.notify('Decompilation failed: No content returned', vim.log.levels.ERROR)
      return
    end

    local buffer_name = string.format('jar://%s.kt', class_name:gsub('%.', '/'))
    local buf = utils.create_readonly_buffer(buffer_name, result.content, 'kotlin')
    decompiled_buffers[uri] = buf
    utils.open_buffer_in_split(buf, split_type)
    vim.notify('Decompilation completed: ' .. class_name, vim.log.levels.INFO)
  end)
end)
```

---

### 3. decompile.lua:92 - 同様の問題（textDocument/definition コールバック）

```lua
client.request('textDocument/definition', params, function(err, result)
  -- ...
  if is_jar_uri(uri) then
    M.decompile_and_show(uri, opts)  -- さらにコールバック内でUI操作
  else
    vim.lsp.buf.definition()  -- UI操作
  end
end)
```

**問題**: コールバック内で `vim.lsp.buf.definition()` を直接呼び出すのは危険。

**修正**: `vim.schedule` で包む。

---

### 4. decompile.lua:104 - vim.islist の誤用

```lua
local location = vim.islist(result) and result[1] or result
```

**問題**:
- `vim.islist` はテーブルが配列形式かをチェックするが、LSPレスポンスは必ずしも純粋な配列ではない
- `result` が `{}` (空テーブル) の場合、`vim.islist({})` は `true` を返すが、`result[1]` は `nil` になる

**影響**: 空の定義リストで `location` が `nil` になり、105行目で `nil.uri` アクセスでクラッシュ。

**修正**: より堅牢なチェック。

```lua
local location
if type(result) == 'table' then
  if result[1] ~= nil then
    location = result[1]
  elseif result.uri or result.targetUri then
    location = result
  end
end

if not location then
  vim.notify('Invalid definition response', vim.log.levels.ERROR)
  return
end

local uri = location.uri or location.targetUri
if not uri then
  vim.notify('Definition location has no URI', vim.log.levels.ERROR)
  return
end
```

---

### 5. decompile.lua:12 - JAR URI判定の不完全性

```lua
return uri:match('^jar:file:') ~= nil or uri:match('%.jar!') ~= nil
```

**問題**:
- `jar:file:` で始まるURIのみを想定しているが、kotlin-lspは異なるスキームを使う可能性
- kotlin-lspの実際のURI形式を確認していない

**テスト必要**: kotlin-lspが実際に返すJAR URIの形式を調査すべき。

**潜在的な問題**: kotlin-lspが `jdt://` などの独自スキームを使う場合、検出に失敗する。

---

## 高優先度の問題（High Priority）

### 6. decompile.lua:16-30 - クラス名抽出ロジックの脆弱性

```lua
local class_path = uri:match('%.jar!/(.+)$') or uri:match('%.jar!(.+)$')
```

**問題**:
- URIが `jar:file:///path/to/lib.jar!/com/example/MyClass.kt` の形式を想定
- `/` で始まるパスの場合、`%.jar!/(.+)$` は `/` を含めてキャプチャするが、クラス名には不要
- ネストされたJAR（JAR内JAR）に対応していない

**修正**:
```lua
local function extract_class_name(uri)
  -- jar:file:///path/to/lib.jar!/com/example/MyClass.kt
  local jar_path = uri:match('%.jar!/?(.+)$')
  if not jar_path then
    return nil
  end

  -- 先頭のスラッシュを除去
  jar_path = jar_path:gsub('^/', '')

  -- 拡張子を除去
  jar_path = jar_path:gsub('%.kt$', ''):gsub('%.class$', ''):gsub('%.java$', '')

  -- パスをクラス名に変換
  local class_name = jar_path:gsub('/', '.')

  return class_name
end
```

---

### 7. decompile.lua:129-135 - キャッシュクリア時の競合状態

```lua
function M.clear_cache()
  for uri, buf in pairs(decompiled_buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  decompiled_buffers = {}
end
```

**問題**:
- `clear_cache()` 実行中に別のデコンパイルが開始されると、競合状態が発生
- デコンパイル中のバッファを強制削除すると、デコンパイル完了時にエラー

**修正**: ロック機構またはデコンパイル中フラグを追加。

---

### 8. decompile.lua:39-46 - キャッシュ検証の不足

```lua
if decompiled_buffers[uri] then
  local buf = decompiled_buffers[uri]
  if vim.api.nvim_buf_is_valid(buf) then
    utils.open_buffer_in_split(buf, split_type)
    return
  else
    decompiled_buffers[uri] = nil
  end
end
```

**問題**:
- バッファが有効でも、内容が古い可能性（JARが更新された場合）
- バッファが別のウィンドウで開かれている場合、新しいsplitを作成するのは冗長

**改善**:
- バッファが既に表示されている場合は、そのウィンドウにジャンプ
- TTLベースのキャッシュ無効化

---

### 9. utils.lua:30 - LSPリクエストのエラーハンドリング不足

```lua
client.request('workspace/executeCommand', params, function(err, result)
  if err then
    vim.notify('Command execution failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
    return
  end
```

**問題**:
- `err` が `nil` でも `result` が不正な可能性
- LSPサーバーがタイムアウトした場合の処理なし
- コールバックが呼ばれない可能性（サーバークラッシュ）

**改善**: タイムアウト処理、result検証。

---

### 10. decompile.lua:174-178 - gd オーバーライドの問題

```lua
vim.keymap.set('n', 'gd', function()
  M.decompile_under_cursor(opts)
end, ...)
```

**問題**:
- `decompile_under_cursor` 内で `vim.lsp.buf.definition()` を呼び出す（111行目）
- これにより、JAR内でない場合、再度 `gd` がトリガーされるのではなく、`vim.lsp.buf.definition()` が呼ばれる
- ユーザーがカスタム `gd` マッピングを持っている場合、上書きされる

**修正**: 元の `gd` の挙動を保存して呼び出す。

```lua
local original_gd = vim.lsp.buf.definition

if opts.override_gd ~= false then
  vim.keymap.set('n', 'gd', function()
    M.decompile_under_cursor(vim.tbl_extend('force', opts, {
      fallback_definition = original_gd
    }))
  end, ...)
end

-- decompile_under_cursor内
else
  if opts.fallback_definition then
    opts.fallback_definition()
  else
    vim.lsp.buf.definition()
  end
end
```

---

## 中優先度の問題（Medium Priority）

### 11. utils.lua:88-89 - ウィンドウ分割の脆弱性

```lua
vim.cmd('vsplit')
...
vim.api.nvim_win_set_buf(0, buf)
```

**問題**:
- `vim.cmd('vsplit')` が失敗する可能性（ウィンドウが作れない）
- `:vsplit` 後、アクティブウィンドウが期待通りか保証されない

**改善**: `vim.api.nvim_open_win` で明示的にウィンドウを作成。

---

### 12. バッファ名の衝突

```lua
local buffer_name = string.format('jar://%s.kt', class_name:gsub('%.', '/'))
```

**問題**: 同じクラス名が異なるJARに存在する場合、バッファ名が衝突。

**改善**: JARパスをバッファ名に含める。

```lua
local jar_path = uri:match('file://(.+%.jar)')
local buffer_name = string.format('jar://%s!/%s.kt', jar_path or 'unknown', class_name:gsub('%.', '/'))
```

---

### 13. メモリリーク

`decompiled_buffers` テーブルはプラグインのライフタイム中、常に成長し続ける可能性。

**改善**: LRUキャッシュ、または弱参照テーブル。

---

### 14. パフォーマンス: 無駄なLSPリクエスト

`decompile_under_cursor` は毎回 `textDocument/definition` を実行するが、既にキャッシュがあればスキップできる可能性。

---

## 低優先度の問題（Low Priority）

### 15. ログの冗長性

```lua
vim.notify('Decompiling: ' .. class_name, vim.log.levels.INFO)
...
vim.notify('Decompilation completed: ' .. class_name, vim.log.levels.INFO)
```

過度な通知はユーザー体験を損なう。

**改善**: オプションで通知レベルを制御。

---

### 16. ドキュメント不足

各関数にLuaDocコメントがない。

---

### 17. テストコードなし

自動テストが存在しない。

---

## アーキテクチャ上の懸念

### 18. decompile.lua:163-189 - setup内でのautocmd作成

`setup()` を複数回呼ぶと、`LspAttach` autocmdが重複登録される。

**修正**: `clear = true` を使用しているため問題ないが、`setup()` の冪等性を保証すべき。

---

### 19. グローバル状態の管理

`decompiled_buffers` がモジュールレベルのグローバル変数。

プラグインを無効化/再ロードした場合、古いキャッシュが残る。

---

## 総合評価

### 実装された機能
- ✅ 基本的なデコンパイル機能
- ✅ コマンド、キーマップ
- ✅ キャッシュ機構

### 重大な欠陥
- ❌ 非推奨API使用（即座に修正必要）
- ❌ コールバック内での非同期UI操作（クラッシュの可能性）
- ❌ LSPレスポンス処理の脆弱性（nil参照クラッシュ）

### 必須の修正事項
1. `vim.api.nvim_buf_set_option` → `vim.bo[buf]`
2. すべてのLSPコールバック内UI操作を `vim.schedule` で包む
3. LSPレスポンスの堅牢な検証
4. JAR URI形式の実際の検証

### 推奨の改善事項
5. クラス名抽出ロジックの改善
6. キャッシュ競合状態の解決
7. バッファ名衝突の回避
8. `gd` オーバーライドの改善

## 次のアクション

1. **即座に修正**: 重大な問題（1-5）
2. **テスト**: kotlin-lspの実際のURI形式を確認
3. **検討**: 高優先度の改善（6-10）
4. **将来**: 中・低優先度の改善
