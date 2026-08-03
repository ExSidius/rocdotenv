#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROC_VERSION="${ROC_VERSION:-alpha4-rolling}"
TOOLS_DIR="$ROOT_DIR/.tools"
BIN_DIR="$TOOLS_DIR/bin"
INSTALL_DIR="$TOOLS_DIR/roc-$ROC_VERSION"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)
    ROC_ARCHIVE="roc-macos_apple_silicon-$ROC_VERSION.tar.gz"
    ;;
  Darwin-x86_64)
    ROC_ARCHIVE="roc-macos_x86_64-$ROC_VERSION.tar.gz"
    ;;
  Linux-aarch64 | Linux-arm64)
    ROC_ARCHIVE="roc-linux_arm64-$ROC_VERSION.tar.gz"
    ;;
  Linux-x86_64)
    ROC_ARCHIVE="roc-linux_x86_64-$ROC_VERSION.tar.gz"
    ;;
  *)
    echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2
    exit 1
    ;;
esac

ROC_URL="https://github.com/roc-lang/roc/releases/download/$ROC_VERSION/$ROC_ARCHIVE"

if [ -x "$INSTALL_DIR/roc" ]; then
  mkdir -p "$BIN_DIR"
  ln -sfn "$INSTALL_DIR/roc" "$BIN_DIR/roc"
  echo "Roc is already installed at $INSTALL_DIR/roc"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to download Roc." >&2
  exit 1
fi

mkdir -p "$TOOLS_DIR" "$BIN_DIR"
TMP_DIR="$(mktemp -d "$TOOLS_DIR/roc-download.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Downloading $ROC_URL"
curl --fail --location --show-error "$ROC_URL" --output "$TMP_DIR/$ROC_ARCHIVE"

echo "Extracting Roc $ROC_VERSION"
tar -xzf "$TMP_DIR/$ROC_ARCHIVE" -C "$TMP_DIR"

EXTRACTED_DIRS=("$TMP_DIR"/*/)
if [ "${#EXTRACTED_DIRS[@]}" -ne 1 ] || [ ! -x "${EXTRACTED_DIRS[0]}roc" ]; then
  echo "Could not find roc executable in downloaded archive." >&2
  exit 1
fi

rm -rf "$INSTALL_DIR"
mv "${EXTRACTED_DIRS[0]}" "$INSTALL_DIR"
ln -sfn "$INSTALL_DIR/roc" "$BIN_DIR/roc"

if command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$INSTALL_DIR/roc" 2>/dev/null || true
fi

echo "Installed Roc at $INSTALL_DIR/roc"
echo "Run: direnv allow"
