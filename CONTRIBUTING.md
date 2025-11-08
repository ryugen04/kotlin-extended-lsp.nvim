# 貢献ガイドライン

kotlin-extended-lsp.nvimへの貢献に興味を持っていただき、ありがとうございます。このドキュメントでは、プロジェクトへの貢献方法について説明します。

## 行動規範

このプロジェクトでは、すべての貢献者に対して敬意と礼儀をもって接することを期待しています。建設的で協力的なコミュニティを維持するため、以下の原則に従ってください。

- 異なる視点や経験を尊重する
- 建設的な批判を受け入れる
- コミュニティにとって最善のことに焦点を当てる
- 他のコミュニティメンバーに共感を示す

## バグ報告

バグを発見した場合は、以下の手順で報告してください。

### 報告前の確認事項

1. 最新バージョンのプラグインを使用しているか確認してください
2. [既存のイシュー](https://github.com/yourusername/kotlin-extended-lsp.nvim/issues)で同じ問題が報告されていないか確認してください
3. `:KotlinExtendedLspHealth`を実行して、プラグインの状態を確認してください

### バグ報告の作成

[バグ報告テンプレート](.github/ISSUE_TEMPLATE/bug_report.md)を使用して、新しいイシューを作成してください。以下の情報を含めることで、問題の解決が早くなります。

- Neovimのバージョン
- JetBrains公式kotlin-lspのバージョン
- プラグインのバージョン
- 再現手順
- 期待される動作
- 実際の動作
- ヘルスチェックの結果
- 関連するログ（デバッグレベル推奨）

## 機能提案

新しい機能のアイデアがある場合は、[機能リクエストテンプレート](.github/ISSUE_TEMPLATE/feature_request.md)を使用してイシューを作成してください。

### 良い機能提案の要素

- 解決したい問題や改善したい点の明確な説明
- 提案する解決策の詳細
- 代替案の検討
- 実装の影響範囲の考慮

## 開発環境のセットアップ

### 必要なツール

- Neovim 0.8以上
- Lua 5.1以上
- [StyLua](https://github.com/JohnnyMorganz/StyLua) - コードフォーマッター
- [Luacheck](https://github.com/mpeterv/luacheck) - 静的解析ツール
- [JetBrains公式kotlin-lsp](https://github.com/Kotlin/kotlin-lsp) - テスト用
  - インストール: `brew install JetBrains/utils/kotlin-lsp`

### 開発環境の構築

1. リポジトリをフォークしてクローンする

```bash
git clone https://github.com/yourusername/kotlin-extended-lsp.nvim.git
cd kotlin-extended-lsp.nvim
```

2. 開発用の依存関係をインストールする

```bash
# StyLua のインストール
cargo install stylua

# Luacheck のインストール
luarocks install luacheck
```

3. プラグインをNeovimの設定にシンボリックリンクする

```bash
# Unixの場合
ln -s $(pwd) ~/.local/share/nvim/site/pack/dev/start/kotlin-extended-lsp.nvim

# または lazy.nvim の dev オプションを使用
{
  dir = '~/path/to/kotlin-extended-lsp.nvim',
  dev = true,
}
```

## コーディング規約

### Luaスタイルガイド

- インデントは2スペースを使用
- 行の最大長は120文字
- StyLuaのデフォルト設定に従う
- 関数とモジュールには適切なコメントを記述

### コメント規約

```lua
-- 単一行コメントは明確で簡潔に

-- 複数行のコメントは、複雑なロジックや
-- 理解が難しい処理について説明する際に使用します。
-- 必要に応じて具体例を含めてください。

--- @param config table ユーザー設定
--- @return boolean 成功した場合はtrue
-- 公開APIには型アノテーションを含むドキュメントコメントを記述
function M.setup(config)
  -- 実装
end
```

### ファイル構成

- 各ファイルの先頭にファイル名と簡単な説明を記述
- モジュールはローカル変数`M`として定義し、最後に`return M`
- 内部関数は`local function`として定義
- 公開関数は`M.function_name`として定義

```lua
-- example.lua
-- 例示モジュールの説明

local M = {}

-- プライベート関数
local function internal_helper()
  -- 実装
end

-- 公開関数
function M.public_function()
  internal_helper()
end

return M
```

## テストガイドライン

### テストの実行

```bash
# すべてのテストを実行
make test

# 特定のテストファイルを実行
nvim --headless -c "luafile tests/test_config.lua"
```

### テストの記述

新しい機能を追加する場合は、対応するテストも追加してください。

```lua
-- tests/test_example.lua
describe('example module', function()
  it('should perform expected behavior', function()
    local example = require('kotlin-extended-lsp.example')
    local result = example.do_something()
    assert.are.equal(expected_value, result)
  end)
end)
```

## プルリクエストプロセス

### プルリクエストを作成する前に

1. すべてのテストが通ることを確認
2. コードフォーマットを実行

```bash
# StyLua でフォーマット
stylua lua/

# Luacheck で静的解析
luacheck lua/
```

3. コミットメッセージが明確で簡潔であることを確認
4. 変更内容を説明するドキュメントを更新

### プルリクエストの作成

1. フォークしたリポジトリに変更をプッシュ
2. GitHubでプルリクエストを作成
3. プルリクエストテンプレートに従って情報を記入
4. レビュアーのフィードバックに対応

### プルリクエストの説明

プルリクエストには以下の情報を含めてください。

- 変更の概要と動機
- 関連するイシュー番号
- テスト方法
- スクリーンショットやログ（該当する場合）
- 破壊的変更がある場合はその説明

### コミットメッセージ規約

明確で一貫性のあるコミットメッセージを使用してください。

```
feat: 新機能の追加
fix: バグ修正
docs: ドキュメントの変更
style: コードスタイルの変更（動作に影響なし）
refactor: リファクタリング
test: テストの追加・修正
chore: ビルドプロセスやツールの変更
```

例:

```
feat: デコンパイル結果のキャッシュ機能を追加

- LRUキャッシュを実装
- キャッシュサイズと有効期限を設定可能に
- :KotlinClearCacheコマンドを追加

Closes #42
```

## コードレビュープロセス

プルリクエストは、以下の基準でレビューされます。

- コードの品質と可読性
- テストの網羅性
- ドキュメントの完全性
- 既存機能への影響
- パフォーマンスへの配慮

レビュアーからのフィードバックには、建設的かつ迅速に対応してください。

## リリースプロセス

メンテナーは以下のプロセスでリリースを行います。

1. バージョン番号を更新（セマンティックバージョニングに従う）
2. CHANGELOGを更新
3. タグを作成してプッシュ
4. GitHubリリースを作成

## 質問とサポート

質問がある場合は、以下の方法でお問い合わせください。

- [GitHub Discussions](https://github.com/yourusername/kotlin-extended-lsp.nvim/discussions) - 一般的な質問や議論
- [Issues](https://github.com/yourusername/kotlin-extended-lsp.nvim/issues) - バグ報告や機能リクエスト

## ライセンス

貢献されたコードは、プロジェクトと同じMITライセンスの下で公開されます。

## 謝辞

貢献してくださるすべての方に感謝します。あなたの時間と労力により、このプロジェクトはより良いものになります。
