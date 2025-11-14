# ジャンプ機能ドキュメント

kotlin-extended-lsp.nvimで実装されているジャンプ機能の詳細ドキュメント

## 概要

kotlin-lspの機能を拡張し、以下の5種類のジャンプ機能を提供します:

1. **定義ジャンプ (Definition)** - `gd`
2. **実装ジャンプ (Implementation)** - `gi`
3. **型定義ジャンプ (Type Definition)** - `gy`
4. **宣言ジャンプ (Declaration)** - `gD`
5. **参照表示 (References)** - `gr`

## 実装詳細

### 1. 定義ジャンプ (Definition Jump)

**ファイル**: `lua/kotlin-extended-lsp/features/decompile.lua`

**実装方法**: デコンパイル機能と統合

**動作**:
1. `textDocument/definition`でシンボルの定義位置を取得
2. 定義がJAR内のファイルの場合、自動的にデコンパイルして表示
3. 通常のKotlinファイルの場合、標準の定義ジャンプ

**キーマップ**: `gd`

**コマンド**: `:KotlinDecompile` (明示的なデコンパイル用)

**使用例**:
```kotlin
val user = userRepository.findById(1) // userRepositoryにカーソルを置いてgd
// → UserRepositoryの定義へジャンプ（JAR内ならデコンパイル）
```

---

### 2. 実装ジャンプ (Implementation Jump)

**ファイル**: `lua/kotlin-extended-lsp/features/implementation.lua`

**実装方法**: 標準LSPメソッド `textDocument/implementation`

**動作**:
1. kotlin-lspが`textDocument/implementation`をサポートしているか確認
2. サポートされていれば`vim.lsp.buf.implementation()`を呼び出し
3. サポートされていなければエラーメッセージを表示

**キーマップ**: `gi`

**コマンド**: `:KotlinGoToImplementation`

**使用例**:
```kotlin
interface UserRepository {  // interface上でgi
    fun findById(id: Long): User?
}

// → UserRepositoryImplクラスの実装へジャンプ
```

**実装の特徴**:
- 単一の実装がある場合: 直接ジャンプ
- 複数の実装がある場合: `vim.ui.select()`で選択UI表示

---

### 3. 型定義ジャンプ (Type Definition Jump)

**ファイル**: `lua/kotlin-extended-lsp/features/type_definition.lua`

**実装方法**: hover + workspace/symbolの組み合わせ（回避策）

**背景**:
kotlin-lspは標準LSPの`textDocument/typeDefinition`をサポートしていないため、以下のアプローチで実装:

1. `textDocument/hover`でカーソル位置の型情報を取得
2. Markdownから型名を抽出
3. `workspace/symbol`で型定義を検索
4. Class/Interface/Enum/Structのみフィルタ
5. 結果が1件なら直接ジャンプ、複数件なら選択UI

**型名抽出の正規表現パターン**:
```lua
local TYPE_PATTERNS = {
  var_decl = ':%s*([%u][%w%.]*)',        -- val name: Type
  func_return = '%)%s*:%s*([%u][%w%.]*)', -- fun name(): Type
  property = 'val%s+%w+%s*:%s*([%u][%w%.]*)', -- val name: Type
  generic = ':%s*([%u][%w%.]*%b<>?)',    -- Type<T>
}
```

**SymbolKindフィルタ**:
```lua
local TYPE_SYMBOL_KINDS = {
  [vim.lsp.protocol.SymbolKind.Class] = true,
  [vim.lsp.protocol.SymbolKind.Interface] = true,
  [vim.lsp.protocol.SymbolKind.Enum] = true,
  [vim.lsp.protocol.SymbolKind.Struct] = true,
}
```

**キーマップ**: `gy`

**コマンド**: `:KotlinGoToTypeDefinition`

**使用例**:
```kotlin
val user: User = userRepository.findById(1) // user変数にカーソルを置いてgy
// → Userクラスの定義へジャンプ

fun getUsers(): List<User> { ... } // 戻り値の型にカーソルを置いてgy
// → Listインターフェースの定義へジャンプ
```

**制限事項**:
- Nullable型 (`User?`) の`?`は自動的に除去される
- ジェネリクスの外側の型のみ抽出される（`List<User>` → `List`）
- hover情報から型名を抽出できない場合は失敗する

---

### 4. 宣言ジャンプ (Declaration Jump)

**ファイル**: `lua/kotlin-extended-lsp/features/declaration.lua`

**実装方法**: 標準LSPメソッド `textDocument/declaration` (フォールバックあり)

**動作**:
1. kotlin-lspが`textDocument/declaration`をサポートしているか確認
2. サポートされていれば`vim.lsp.buf.declaration()`を呼び出し
3. サポートされていなければ`vim.lsp.buf.definition()`にフォールバック

**キーマップ**: `gD` (デフォルトでは無効)

**コマンド**: `:KotlinGoToDeclaration`

**注意事項**:
- Kotlinでは宣言と定義が一体化しているため、実用性は低い
- 多くの場合、`gd` (定義ジャンプ) で十分
- キーマップはデフォルトで無効（`setup({ declaration = { setup_keymaps = true } })`で有効化可能）

---

### 5. 参照表示 (References)

**実装**: Neovim標準のLSP機能を使用

**キーマップ**: `gr`

**動作**:
1. `textDocument/references`でシンボルの参照箇所を取得
2. QuickFixリストまたはLocation Listに表示

**使用例**:
```kotlin
class User { ... } // Userクラスの定義でgr
// → プロジェクト内のすべてのUser参照箇所を表示
```

---

## キーマップ一覧

| キー | 機能 | 説明 |
|------|------|------|
| `gd` | 定義ジャンプ | シンボルの定義へジャンプ（JAR内ならデコンパイル） |
| `gi` | 実装ジャンプ | インターフェース/抽象クラスの実装へジャンプ |
| `gy` | 型定義ジャンプ | 変数/プロパティの型定義へジャンプ |
| `gD` | 宣言ジャンプ | シンボルの宣言へジャンプ（デフォルト無効） |
| `gr` | 参照表示 | シンボルの参照箇所を表示 |
| `K` | ホバー情報 | カーソル位置のシンボル情報を表示 |
| `<leader>kd` | 明示的デコンパイル | カーソル位置のシンボルをデコンパイル |

---

## コマンド一覧

| コマンド | 機能 |
|----------|------|
| `:KotlinGoToImplementation` | 実装ジャンプ |
| `:KotlinGoToTypeDefinition` | 型定義ジャンプ |
| `:KotlinGoToDeclaration` | 宣言ジャンプ |
| `:KotlinDecompile [URI]` | デコンパイル |
| `:KotlinDecompileClearCache` | デコンパイルキャッシュのクリア |

---

## 設定オプション

### プラグインのsetup

```lua
require('kotlin-extended-lsp').setup({
  -- デコンパイル機能（定義ジャンプに統合）
  enable_decompile = true,  -- デフォルト: true
  decompile = {
    setup_keymaps = true,     -- gd, <leader>kd を設定
    override_gd = true,       -- gdをデコンパイル対応にする
    split_type = 'vertical',  -- 'vertical', 'horizontal', 'tab'
  },

  -- 型定義ジャンプ
  enable_type_definition = true,  -- デフォルト: true
  type_definition = {
    setup_keymaps = true,     -- gy を設定
  },

  -- 実装ジャンプ
  enable_implementation = true,  -- デフォルト: true
  implementation = {
    setup_keymaps = true,     -- gi を設定
  },

  -- 宣言ジャンプ
  enable_declaration = true,  -- デフォルト: true
  declaration = {
    setup_keymaps = false,    -- デフォルト: false（gDは設定しない）
  },
})
```

### 個別機能の無効化

```lua
require('kotlin-extended-lsp').setup({
  enable_type_definition = false,   -- 型定義ジャンプを無効化
  enable_implementation = false,    -- 実装ジャンプを無効化
  enable_declaration = false,       -- 宣言ジャンプを無効化
})
```

---

## 実装アルゴリズム

### 型定義ジャンプのフロー

```
1. カーソル位置の取得
   ↓
2. textDocument/hover リクエスト
   ↓
3. Markdownレスポンスから型名を抽出
   - 正規表現パターンマッチング
   - Nullable型の ? を除去
   - ジェネリクスの外側を抽出
   ↓
4. workspace/symbol リクエスト (query: 型名)
   ↓
5. SymbolKindでフィルタ
   - Class, Interface, Enum, Struct のみ
   ↓
6. 結果が1件の場合:
   - vim.lsp.util.jump_to_location() で直接ジャンプ
   ↓
7. 結果が複数件の場合:
   - vim.ui.select() で選択UI表示
   - ユーザーが選択後にジャンプ
   ↓
8. 結果が0件の場合:
   - エラーメッセージを表示
```

### 実装ジャンプのフロー

```
1. kotlin-lspクライアントを取得
   ↓
2. textDocument/implementation サポート確認
   - client.supports_method('textDocument/implementation')
   ↓
3. サポートされている場合:
   - vim.lsp.buf.implementation() を呼び出し
   - Neovimが自動的に結果を処理
   ↓
4. サポートされていない場合:
   - エラーメッセージを表示
```

---

## トラブルシューティング

### 型定義ジャンプが動作しない

**症状**: `gy` を押しても「型名を抽出できません」というエラーが出る

**原因**:
- hover情報が取得できない
- Markdownから型名を抽出できない

**解決策**:
1. `K` (hover) で型情報が表示されるか確認
2. hover情報に型名が含まれているか確認
3. 型名が大文字で始まっているか確認（Kotlinの命名規則）

### 実装ジャンプが動作しない

**症状**: `gi` を押しても「kotlin-lsp does not support textDocument/implementation」というエラーが出る

**原因**:
- kotlin-lspが`textDocument/implementation`をサポートしていない

**解決策**:
1. kotlin-lspのバージョンを確認: `kotlin-lsp --version`
2. 最新版にアップデート: `./scripts/install-lsp.sh`
3. LSPのcapabilitiesを確認:
   ```lua
   :lua =vim.lsp.get_active_clients()[1].server_capabilities
   ```

### 複数結果から選択できない

**症状**: 型定義ジャンプで複数の候補が表示されるが、選択UIが表示されない

**原因**:
- `vim.ui.select()`が正しく動作していない
- telescope.nvim や dressing.nvim が導入されていない可能性

**解決策**:
1. telescope.nvim または dressing.nvim をインストール
2. Neovim標準のselect UIを使用する場合は何もしなくてOK

---

## パフォーマンス考慮事項

### 型定義ジャンプ

- **2つのLSPリクエスト**を送信するため、若干の遅延が発生する可能性
  1. `textDocument/hover` - 型情報の取得
  2. `workspace/symbol` - 型定義の検索

- **最適化**:
  - リクエストは非同期で処理される
  - `vim.schedule()`でUI操作を安全に実行

### 実装ジャンプ

- **1つのLSPリクエスト**のみで完結
- Neovim標準の`vim.lsp.buf.implementation()`を使用するため高速

### デコンパイル（定義ジャンプ）

- **キャッシュ機構**により、同じJARファイルの再デコンパイルを防ぐ
- デコンパイル済みバッファはメモリ上に保持される
- `:KotlinDecompileClearCache`でキャッシュをクリア可能

---

## 今後の改善案

### 型定義ジャンプの改善

1. **より多くの型パターンに対応**
   - ラムダ式の型推論
   - 複雑なジェネリクス (`Map<String, List<User>>`)
   - Nullable型の詳細な処理

2. **treesitterとの統合**
   - hover情報に依存せず、treesitterで型を直接解析
   - より正確な型名抽出

3. **キャッシュ機構**
   - hover結果をキャッシュして高速化

### 実装ジャンプの改善

1. **フォールバック実装**
   - kotlin-lspがサポートしていない場合の代替アプローチ
   - treesitterを使った実装検索

2. **スーパークラス/インターフェースへのジャンプ**
   - 実装クラスから親インターフェースへ逆方向のジャンプ

### 宣言ジャンプの改善

1. **実用性の検証**
   - Kotlinでの実際の使用ケースを調査
   - 必要性が低ければ削除を検討

---

## 参考資料

### LSP仕様
- [textDocument/definition](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_definition)
- [textDocument/implementation](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_implementation)
- [textDocument/typeDefinition](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_typeDefinition)
- [textDocument/declaration](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_declaration)

### kotlin-lsp
- [公式リポジトリ](https://github.com/Kotlin/kotlin-lsp)
- [コミュニティ版](https://github.com/fwcd/kotlin-language-server)

### Neovim LSP
- [vim.lsp.buf ドキュメント](https://neovim.io/doc/user/lsp.html)
- [LSP設定ガイド](https://github.com/neovim/nvim-lspconfig)

---

最終更新: 2025-11-11
