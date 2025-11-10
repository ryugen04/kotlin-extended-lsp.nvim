#!/usr/bin/env bash
# kotlin-lsp インストールスクリプト

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PLUGIN_ROOT/bin"
KOTLIN_LSP_DIR="$BIN_DIR/kotlin-lsp"

echo "=== kotlin-lsp インストール ==="

# 既存のインストールをチェック
if [ -d "$KOTLIN_LSP_DIR" ]; then
    echo "既存のkotlin-lspが見つかりました: $KOTLIN_LSP_DIR"
    read -p "再インストールしますか? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "インストールをキャンセルしました"
        exit 0
    fi
    rm -rf "$KOTLIN_LSP_DIR"
fi

# 一時ディレクトリを作成
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

cd "$TMP_DIR"

echo "kotlin-lsp Standaloneをダウンロード中..."

# 最新リリースバージョンを取得
RELEASE_URL="https://api.github.com/repos/Kotlin/kotlin-lsp/releases/latest"
VERSION=$(curl -s "$RELEASE_URL" | grep '"tag_name"' | sed -E 's/.*"tag_name": "kotlin-lsp\/v([0-9.]+)".*/\1/')

if [ -z "$VERSION" ]; then
    echo "エラー: バージョン情報を取得できませんでした"
    exit 1
fi

DOWNLOAD_URL="https://download-cdn.jetbrains.com/kotlin-lsp/$VERSION/kotlin-$VERSION.zip"

echo "バージョン: $VERSION"
echo "ダウンロード: $DOWNLOAD_URL"
curl -L -o kotlin-lsp.zip "$DOWNLOAD_URL"

# ファイルサイズをチェック（9バイト以下ならエラー）
FILE_SIZE=$(stat -f%z kotlin-lsp.zip 2>/dev/null || stat -c%s kotlin-lsp.zip 2>/dev/null)
if [ "$FILE_SIZE" -lt 100 ]; then
    echo "エラー: ダウンロードに失敗しました（ファイルサイズ: $FILE_SIZE バイト）"
    exit 1
fi

echo "解凍中..."
unzip -q kotlin-lsp.zip

# 解凍構造を確認
if [ ! -f "kotlin-lsp.sh" ] || [ ! -d "lib" ]; then
    echo "エラー: 予期しない解凍構造です"
    echo "現在のディレクトリ内容:"
    ls -la
    exit 1
fi

echo "解凍完了"

# binディレクトリを作成
mkdir -p "$KOTLIN_LSP_DIR"

# ファイルを移動
mv kotlin-lsp.sh kotlin-lsp.cmd lib native "$KOTLIN_LSP_DIR/"

# 起動スクリプトに実行権限を付与
chmod +x "$KOTLIN_LSP_DIR/kotlin-lsp.sh"

echo "✓ インストール完了: $KOTLIN_LSP_DIR"
echo ""
echo "kotlin-lspのバージョン:"
"$KOTLIN_LSP_DIR/kotlin-lsp.sh" --version 2>&1 | head -3 || echo "(バージョン情報を取得できませんでした)"

echo ""
echo "=== インストール成功 ==="
