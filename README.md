# kotlin-extended-lsp.nvim

JetBrains公式kotlin-lspをNeovimで使用するための最小限のプラグイン

## 特徴

- JetBrains公式kotlin-lsp (Standalone版) の統合
- 自動インストールスクリプト付属
- Gradleプロジェクトの自動検出とインデックス化
- 基本的なLSP機能（定義ジャンプ、ホバー、補完、リファレンス等）

## インストール

### 1. プラグインマネージャーで追加

**lazy.nvimの場合**:

```lua
{
  'your-username/kotlin-extended-lsp.nvim',
  ft = 'kotlin',
  config = function()
    require('kotlin-extended-lsp').setup()
  end
}
```

**ローカル開発の場合**:

```lua
{
  dir = '~/dev/projects/kotlin-extended-lsp.nvim',
  ft = 'kotlin',
  config = function()
    require('kotlin-extended-lsp').setup()
  end
}
```

### 2. kotlin-lspをインストール

プラグインディレクトリに移動してインストールスクリプトを実行します:

```bash
cd ~/.local/share/nvim/lazy/kotlin-extended-lsp.nvim
./scripts/install-lsp.sh
```

スクリプトは以下を自動的に実行します:
- JetBrains公式リポジトリから最新版をダウンロード
- `bin/kotlin-lsp/`に展開
- 実行権限を設定
- 一時ファイルをクリーンアップ

## 使用方法

Kotlinファイルを開くと自動的にkotlin-lspが起動します。

### 基本機能

プラグインは以下を自動で行います:

1. **プロジェクトルート検出**: `build.gradle.kts`, `settings.gradle.kts`などを基準に検出
2. **LSPサーバー起動**: 検出したルートディレクトリで kotlin-lsp を起動
3. **Gradleプロジェクトインポート**: 依存関係を自動的にインデックス化

### キーマップ

デフォルトで以下のキーマップが設定されます:

- `gd` - 定義へジャンプ
- `K` - ホバー情報を表示
- `gi` - 実装へジャンプ
- `gr` - リファレンスを表示
- `<leader>rn` - リネーム
- `<leader>ca` - コードアクション

## 要件

- Neovim 0.10+
- Java 17+ (kotlin-lspの実行に必要)
- Kotlin Gradleプロジェクト

## プロジェクト構造

```
kotlin-extended-lsp.nvim/
├── bin/
│   └── kotlin-lsp/          # LSPバイナリ (gitignore対象)
│       ├── kotlin-lsp.sh    # 起動スクリプト
│       ├── lib/             # JARファイル
│       └── native/          # ネイティブライブラリ
├── lua/
│   └── kotlin-extended-lsp/
│       └── init.lua         # メインプラグイン実装
├── scripts/
│   └── install-lsp.sh       # インストールスクリプト
├── .gitignore
└── README.md
```

## トラブルシューティング

### LSPが起動しない

1. kotlin-lspが正しくインストールされているか確認:
   ```bash
   ls -la bin/kotlin-lsp/
   ```

2. Javaがインストールされているか確認:
   ```bash
   java -version  # Java 17以上が必要
   ```

3. LSPログを確認:
   ```vim
   :lua print(vim.lsp.get_log_path())
   ```

### プロジェクトルートが検出されない

プロジェクトルートに以下のいずれかのファイルがあることを確認してください:
- `settings.gradle.kts`
- `settings.gradle`
- `build.gradle.kts`
- `build.gradle`
- `pom.xml`

## 既知の制限事項

kotlin-lsp v0.253.10629は現在**pre-alphaステータス**です:

- Gradle依存関係の解決が不完全な場合があります
- 一部の外部ライブラリで補完が効かない場合があります
- IntelliJ IDEA/Android Studioと比較して機能が限定的です

より安定したLSPが必要な場合は、コミュニティ版の `fwcd/kotlin-language-server` も検討してください。

## ライセンス

MIT
