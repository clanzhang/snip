#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="$HOME/.local/bin"
BINARY="$PROJECT_DIR/.build/release/snip"

echo "=== Snip 安装 ==="

# 编译
echo "编译中..."
cd "$PROJECT_DIR"
swiftc -o "$BINARY" Sources/Snip/*.swift -framework AppKit -framework Foundation -framework Carbon

# 安装目录
mkdir -p "$INSTALL_DIR"
cp "$BINARY" "$INSTALL_DIR/snip"
chmod +x "$INSTALL_DIR/snip"

# 脚本
cp "$PROJECT_DIR/scripts/snip" "$INSTALL_DIR/snip-ctl"
chmod +x "$INSTALL_DIR/snip-ctl"

# 添加到 ~/.zshrc
if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    echo "已将 ~/.local/bin 添加到 ~/.zshrc"
fi

echo "安装完成: $INSTALL_DIR/snip"
echo "运行: source ~/.zshrc && snip --help"