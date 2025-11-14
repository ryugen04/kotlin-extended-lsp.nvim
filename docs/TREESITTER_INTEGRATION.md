# Treesitterベースのジャンプ機能統合

kotlin-extended-lsp.nvimにTreesitterベースのジャンプ機能を統合しました。

## 概要

従来のLSPベースのジャンプ機能を改善し、Treesitterによるファイル内高速解析とLSPによるプロジェクトワイドな解析を組み合わせたハイブリッドアプローチを実装しました。

### 実装された機能

1. **Treesitterベースのファイル内定義ジャンプ**
   - ファイル内のローカル変数、関数、クラスの定義を高速に解決
   - スコープを考慮した正確な定義検索
   - LSPへの自動フォールバック

2. **Treesitterベースの型定義ジャンプ**
   - 型アノテーションから直接型名を抽出
   - hover情報への依存を削減
   - より正確なジェネリクスとNullable型の処理

3. **LSPフォールバック機構**
   - Treesitterで解決できない場合、自動的にLSPを使用
   - クロスファイル参照やライブラリ参照に対応
   - Treesitterが利用不可の環境でも動作

## 実装アーキテクチャ

### モジュール構成

```
lua/kotlin-extended-lsp/
├── ts_utils.lua                 # Treesitterユーティリティ（新規）
├── features/
│   ├── ts_definition.lua        # Treesitterベースのジャンプ機能（新規）
│   ├── type_definition.lua      # LSPベースの型定義ジャンプ（既存・フォールバック用）
│   ├── implementation.lua       # 実装ジャンプ（既存）
│   └── declaration.lua          # 宣言ジャンプ（既存）
└── init.lua                     # メイン統合（更新）
```

### ts_utils.lua - Treesitterユーティリティ

nvim-treesitter-refactorのアプローチを参考にした実装です。

**主要機能**:

1. **スコープ解析**
   ```lua
   get_parent_scope(node, bufnr)  -- 親スコープを取得
   iter_scope_tree(node, bufnr)   -- スコープツリーをイテレート
   ```

2. **定義検索**
   ```lua
   find_definition(node, bufnr)   -- カーソル位置のシンボルの定義を検索
   get_definitions_lookup_table(bufnr)  -- 定義のルックアップテーブル構築
   ```

3. **型情報抽出**
   ```lua
   get_type_annotation_at_cursor(bufnr)  -- カーソル位置の型アノテーションを取得
   extract_type_from_node(node, bufnr)   -- ノードから型情報を抽出
   find_type_definition_in_file(type_name, bufnr)  -- ファイル内の型定義を検索
   ```

**使用するTreesitterクエリ**:

`~/.local/share/nvim/lazy/nvim-treesitter/queries/kotlin/locals.scm`を使用：

- `@local.definition.function` - 関数定義
- `@local.definition.method` - メソッド定義
- `@local.definition.type` - 型定義
- `@local.definition.var` - 変数定義
- `@local.definition.field` - フィールド定義
- `@local.definition.parameter` - パラメータ定義
- `@local.scope` - スコープ境界

### ts_definition.lua - ハイブリッドジャンプ機能

**定義ジャンプのアルゴリズム**:

```
1. Treesitterが利用可能かチェック
   ↓
2. カーソル位置のノードを取得
   ↓
3. スコープツリーを上方に走査して定義を検索
   ↓
4. 見つかった場合: ジャンプ
   ↓
5. 見つからない場合: LSPにフォールバック
   - クロスファイル参照
   - ライブラリ参照
   - import解決
```

**型定義ジャンプのアルゴリズム**:

```
1. Treesitterが利用可能かチェック
   ↓
2. カーソル位置の型アノテーションを抽出
   - property_declaration: val x: Type
   - function_declaration: fun f(): Type
   - parameter: (param: Type)
   ↓
3. Nullable型の ? を除去
   ↓
4. ジェネリクスの外側の型を抽出
   - List<User> → List
   ↓
5. ファイル内で型定義を検索
   ↓
6. 見つかった場合:
   - 単一結果: 直接ジャンプ
   - 複数結果: vim.ui.select()で選択
   ↓
7. 見つからない場合: LSP-basedの実装にフォールバック
```

## 設定方法

### 基本設定（Treesitter有効）

```lua
require('kotlin-extended-lsp').setup({
  -- Treesitterベースのジャンプ機能を有効化（デフォルト）
  enable_ts_definition = true,  -- これがtrueの場合、gdとgyを上書き

  -- Treesitterのオプション
  ts_definition = {
    setup_keymaps = true,      -- gdとgyをTreesitter版に設定
    override_gd = true,         -- gdを上書き
    override_gy = true,         -- gyを上書き
    create_commands = false,    -- :KotlinTsGoToDefinition コマンドを作成（デフォルト: false）
  },

  -- LSPベースの型定義ジャンプはフォールバック用に保持
  enable_type_definition = true,
})
```

### Treesitterを無効化（LSPのみ使用）

```lua
require('kotlin-extended-lsp').setup({
  -- Treesitterベースのジャンプ機能を無効化
  enable_ts_definition = false,

  -- LSPベースの機能のみ使用
  enable_type_definition = true,
  type_definition = {
    setup_keymaps = true,
  },
})
```

### カスタムキーマップ

```lua
require('kotlin-extended-lsp').setup({
  ts_definition = {
    setup_keymaps = false,  -- 自動キーマップを無効化
  },
})

-- 手動でキーマップを設定
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == 'kotlin-lsp' then
      local ts_def = require('kotlin-extended-lsp.features.ts_definition')
      vim.keymap.set('n', '<leader>gd', ts_def.goto_definition, { buffer = args.buf })
      vim.keymap.set('n', '<leader>gy', ts_def.goto_type_definition, { buffer = args.buf })
    end
  end
})
```

## 動作要件

### 必須要件

- Neovim 0.10+ (Treesitter統合のため)
- kotlin-lsp（既存の要件）

### オプション（推奨）

- nvim-treesitter プラグイン
- tree-sitter-kotlin パーサー

インストール方法:

```lua
-- lazy.nvim
{
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter.configs').setup({
      ensure_installed = { 'kotlin', 'lua', 'vim' },
      highlight = { enable = true },
    })
  end
}
```

または手動インストール:

```vim
:TSInstall kotlin
```

### Treesitterなしでの動作

Treesitterがインストールされていない、またはKotlinパーサーが利用不可の場合:

- 自動的にLSPベースの実装にフォールバック
- 全ての機能が引き続き動作（従来通り）
- 通知メッセージで状況を表示

```
Treesitter not available, falling back to LSP
```

## パフォーマンス比較

### Treesitter版の利点

1. **ファイル内検索が高速**
   - LSPリクエストなし
   - ローカルASTを直接走査
   - レスポンスタイムの削減

2. **正確なスコープ解決**
   - 変数のシャドーイングに対応
   - ネストした関数/ラムダ内の定義を正確に検索

3. **ネットワーク不要**
   - LSPサーバーが一時的に応答しない場合でも動作

### LSP版の利点（フォールバック）

1. **プロジェクトワイド検索**
   - 他のファイルの定義を検索
   - import解決
   - ライブラリの型定義

2. **型推論のサポート**
   - 暗黙的な型の解決
   - ジェネリクスの具体化
   - 複雑な型システムのサポート

## 実装の制限事項

### Treesitter版

1. **ファイル単位の解析**
   - クロスファイル参照は未対応 → LSPにフォールバック
   - import文の解決は未対応 → LSPにフォールバック

2. **型推論の限界**
   - 明示的な型アノテーションのみ抽出可能
   - 暗黙的な型推論は未対応 → LSPにフォールバック

3. **ジェネリクスの扱い**
   - 外側の型のみ抽出（`List<User>` → `List`）
   - 型パラメータの具体化は未対応

### LSP版（既存の制限）

1. **型定義ジャンプ**
   - hover情報に依存（kotlin-lspが`textDocument/typeDefinition`を未サポート）
   - 正規表現での型名抽出

2. **実装ジャンプ**
   - kotlin-lspのサポート状況に依存

## トラブルシューティング

### Treesitterが動作しない

**症状**: `Treesitter not available` の通知が表示される

**確認事項**:

1. nvim-treesitterがインストールされているか:
   ```vim
   :lua print(pcall(require, 'nvim-treesitter'))
   ```

2. Kotlinパーサーがインストールされているか:
   ```vim
   :lua print(vim.treesitter.language.get_lang('kotlin'))
   ```

3. パーサーファイルの存在確認:
   ```bash
   find ~/.local/share/nvim -name "kotlin.so"
   ```

**解決方法**:

```vim
:TSInstall kotlin
```

### locals.scmが見つからない

**症状**: `No query file for 'kotlin'` エラー

**確認事項**:
```bash
find ~/.local/share/nvim -name "locals.scm" -path "*/queries/kotlin/*"
```

**解決方法**:

nvim-treesitterを最新版に更新:

```vim
:TSUpdate kotlin
```

### フォールバックが常に発生する

**症状**: 常にLSPフォールバックが実行される

**原因**:

1. Kotlinパーサーが正しくインストールされていない
2. locals.scmが見つからない
3. ファイル内に定義が存在しない（正常な動作）

**デバッグ方法**:

```lua
-- デバッグ出力を有効化
vim.lsp.set_log_level('debug')
```

## 今後の改善案

### Phase 1: 完了 ✅

- ✅ Treesitterユーティリティの実装
- ✅ ファイル内定義ジャンプ
- ✅ 型定義ジャンプのTreesitter化
- ✅ LSPフォールバック機構

### Phase 2: 検討中

- [ ] プロジェクトワイドのシンボルインデックス
  - プロジェクト初期化時にインデックスを構築
  - ファイル変更時のインクリメンタル更新
  - クロスファイル参照の解決

- [ ] import解決の改善
  - Gradleプロジェクト構造の解析
  - 同一プロジェクト内のimport解決
  - 外部ライブラリはLSPに委譲

- [ ] 型推論の限定的サポート
  - リテラルベースの型推論
  - 標準ライブラリ関数のシグネチャマップ
  - 型アノテーションの伝播

### Phase 3: 長期的改善

- [ ] キャッシング機構の実装
  - 定義ルックアップテーブルのキャッシュ
  - ファイル変更検出とキャッシュ無効化

- [ ] パフォーマンス最適化
  - 非同期パース
  - インクリメンタル解析

- [ ] 高度な機能
  - スーパークラス/インターフェースへのジャンプ
  - 使用箇所の検索
  - リファクタリング支援

## 参考資料

### 実装の参考にしたプラグイン

- [nvim-treesitter-refactor](https://github.com/nvim-treesitter/nvim-treesitter-refactor) - スコープ解析のアルゴリズム
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) - ノード走査のパターン
- [navigator.lua](https://github.com/ray-x/navigator.lua) - LSPとTreesitterの統合方法

### ドキュメント

- [Neovim Treesitter](https://neovim.io/doc/user/treesitter.html)
- [Tree-sitter公式](https://tree-sitter.github.io/)
- [tree-sitter-kotlin](https://github.com/fwcd/tree-sitter-kotlin)
- [nvim-treesitter queries](https://github.com/nvim-treesitter/nvim-treesitter/tree/master/queries)

---

最終更新: 2025-11-11
