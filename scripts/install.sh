#!/bin/bash
# ===========================================
# ClipDoctor 安装脚本
# 将 clipdoctor 安装到 /usr/local/bin
# ===========================================
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/.build/release/clipdoctor"

echo "=== ClipDoctor 安装 ==="
echo ""

# 1. 编译
echo "📦 编译中..."
mkdir -p "$(dirname "$BINARY")"
swiftc -O -whole-module-optimization \
    -o "$BINARY" \
    "$PROJECT_DIR/Sources/clipdoctor/"*.swift \
    -framework AppKit \
    -framework Foundation

if [ ! -f "$BINARY" ]; then
    echo "❌ 编译失败"
    exit 1
fi
echo "✅ 编译完成"

# 2. 安装二进制
echo ""
echo "📁 安装到 $INSTALL_DIR/clipdoctor ..."
mkdir -p "$INSTALL_DIR"
cp "$BINARY" "$INSTALL_DIR/clipdoctor"
chmod +x "$INSTALL_DIR/clipdoctor"

# 3. 安装 snip 管理脚本
echo "📁 安装 snip 命令到 $INSTALL_DIR/snip ..."
cp "$SCRIPT_DIR/snip" "$INSTALL_DIR/snip"
chmod +x "$INSTALL_DIR/snip"

echo "✅ 安装完成"

# 4. 检查 PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qxF "$INSTALL_DIR"; then
    echo ""
    echo "⚠️  $INSTALL_DIR 不在 PATH 中，请将以下行添加到 ~/.zshrc 或 ~/.bashrc："
    echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
fi

# 5. 创建日志目录
mkdir -p "$HOME/.cmdcv"
echo ""
echo "📝 日志目录: $HOME/.cmdcv/"

echo ""
echo "🎉 安装完成！运行方式："
echo "   snip start              # 后台启动监控"
echo "   snip stop               # 停止监控"
echo "   snip status             # 查看状态"
echo "   snip log                # 实时查看日志"
echo "   snip restart            # 重启"
echo ""
echo "   日志文件: ~/.cmdcv/monitor.log"