#!/usr/bin/env bash
# kotlin-lsp インストールスクリプト

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PLUGIN_ROOT/bin"
KOTLIN_LSP_DIR="$BIN_DIR/kotlin-lsp"

echo "=== kotlin-lsp インストール ==="

VERSION_ARG=""
FORCE_REINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION_ARG="$2"
            shift 2
            ;;
        --latest)
            VERSION_ARG="latest"
            shift
            ;;
        --force)
            FORCE_REINSTALL=true
            shift
            ;;
        *)
            echo "不明なオプション: $1"
            echo "Usage: $0 [--version <version>] [--latest] [--force]"
            exit 1
            ;;
    esac
done

# 既存のインストールをチェック
if [ -d "$KOTLIN_LSP_DIR" ]; then
    echo "既存のkotlin-lspが見つかりました: $KOTLIN_LSP_DIR"
    if [ "$FORCE_REINSTALL" = false ]; then
        read -p "再インストールしますか? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "インストールをキャンセルしました"
            exit 0
        fi
    fi
    rm -rf "$KOTLIN_LSP_DIR"
fi

# 一時ディレクトリを作成
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

cd "$TMP_DIR"

echo "kotlin-lsp Standaloneをダウンロード中..."

VERSION="$VERSION_ARG"
if [ -z "$VERSION" ] || [ "$VERSION" = "latest" ]; then
    # 最新リリースバージョンを取得
    RELEASE_URL="https://api.github.com/repos/Kotlin/kotlin-lsp/releases/latest"
    VERSION=$(curl -s "$RELEASE_URL" | grep '"tag_name"' | sed -E 's/.*"tag_name": "kotlin-lsp\/v?([0-9.]+)".*/\1/')
fi

# バージョン表記の正規化
VERSION=$(echo "$VERSION" | sed -E 's/^kotlin-lsp\///; s/^v//')

if [ -z "$VERSION" ]; then
    echo "エラー: バージョン情報を取得できませんでした"
    exit 1
fi

DOWNLOAD_URLS=(
    "https://download-cdn.jetbrains.com/kotlin-lsp/$VERSION/kotlin-$VERSION.zip"
    "https://download-cdn.jetbrains.com/kotlin-lsp/$VERSION/kotlin-lsp-$VERSION.zip"
    "https://download.jetbrains.com/kotlin-lsp/$VERSION/kotlin-$VERSION.zip"
    "https://download.jetbrains.com/kotlin-lsp/$VERSION/kotlin-lsp-$VERSION.zip"
)

echo "バージョン: $VERSION"

is_zip() {
    local file="$1"
    local sig
    sig=$(od -An -t x1 -N 2 "$file" 2>/dev/null | tr -d ' \n')
    [ "$sig" = "504b" ]
}

download_ok=false
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH_NAME=$(uname -m | tr '[:upper:]' '[:lower:]')

PLATFORM=""
if [[ "$OS_NAME" == "darwin" ]]; then
    if [[ "$ARCH_NAME" == "arm64" || "$ARCH_NAME" == "aarch64" ]]; then
        PLATFORM="mac-aarch64"
    else
        PLATFORM="mac-x64"
    fi
elif [[ "$OS_NAME" == "linux" ]]; then
    if [[ "$ARCH_NAME" == "arm64" || "$ARCH_NAME" == "aarch64" ]]; then
        PLATFORM="linux-aarch64"
    else
        PLATFORM="linux-x64"
    fi
elif [[ "$OS_NAME" == "msys" || "$OS_NAME" == "mingw"* || "$OS_NAME" == "cygwin"* ]]; then
    if [[ "$ARCH_NAME" == "arm64" || "$ARCH_NAME" == "aarch64" ]]; then
        PLATFORM="win-aarch64"
    else
        PLATFORM="win-x64"
    fi
fi

if [ -n "$PLATFORM" ]; then
    DOWNLOAD_URLS=(
        "https://download-cdn.jetbrains.com/kotlin-lsp/$VERSION/kotlin-lsp-$VERSION-$PLATFORM.zip"
        "https://download.jetbrains.com/kotlin-lsp/$VERSION/kotlin-lsp-$VERSION-$PLATFORM.zip"
        "${DOWNLOAD_URLS[@]}"
    )
fi

for url in "${DOWNLOAD_URLS[@]}"; do
    echo "ダウンロード: $url"
    if curl -fL -A "kotlin-extended-lsp-installer" -o kotlin-lsp.zip "$url"; then
        if is_zip kotlin-lsp.zip; then
            download_ok=true
            break
        else
            echo "警告: 取得ファイルがzipではありません"
            head -c 200 kotlin-lsp.zip || true
            echo
        fi
    else
        echo "警告: ダウンロードに失敗しました"
    fi
done

if [ "$download_ok" = false ]; then
    echo "エラー: 有効なkotlin-lsp zipを取得できませんでした"
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
if [ -d "jre" ]; then
    mv jre "$KOTLIN_LSP_DIR/"
fi
if [ -d "jbr" ]; then
    mv jbr "$KOTLIN_LSP_DIR/"
fi

# 起動スクリプトに実行権限を付与
chmod +x "$KOTLIN_LSP_DIR/kotlin-lsp.sh"

# bundled JREがない場合はシステムJavaへフォールバックするようにパッチ
if [ ! -d "$KOTLIN_LSP_DIR/jre" ] && [ ! -d "$KOTLIN_LSP_DIR/jbr" ]; then
    python3 - <<'PY'
from pathlib import Path
path = Path("scripts/install-lsp.sh").resolve()
bin_dir = path.parent.parent / "bin" / "kotlin-lsp" / "kotlin-lsp.sh"
if not bin_dir.exists():
    raise SystemExit(0)
text = bin_dir.read_text()
old = """else
    echo >&2 -e "'java' was not found at $LOCAL_JRE_PATH, installation corrupted"
    exit 1
fi
"""
new = """else
    if [ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ]; then
        JAVA_BIN="$JAVA_HOME/bin/java"
    elif command -v java >/dev/null 2>&1; then
        JAVA_BIN="$(command -v java)"
    else
        echo >&2 -e "'java' was not found at $LOCAL_JRE_PATH, installation corrupted"
        exit 1
    fi
fi
"""
if old in text:
    bin_dir.write_text(text.replace(old, new))
PY
fi

echo "✓ インストール完了: $KOTLIN_LSP_DIR"

# バージョン情報を保存
echo "$VERSION" > "$KOTLIN_LSP_DIR/VERSION"

echo ""
echo "kotlin-lspのバージョン: $VERSION"

echo ""
echo "=== インストール成功 ==="
