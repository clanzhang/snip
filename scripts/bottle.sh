#!/bin/bash
# 生成并发布 Homebrew bottle
# 用法: bash scripts/bottle.sh v0.1.6
set -e

VERSION="${1:?请指定版本号，例如: bash scripts/bottle.sh v0.1.6}"

echo "=== 1. 安装并构建 bottle ==="
brew install --build-bottle clanzhang/tap/snip

echo ""
echo "=== 2. 生成 bottle ==="
brew bottle clanzhang/tap/snip

echo ""
echo "=== 3. 上传 bottle 到 GitHub Releases ==="
BOTTLE_FILE=$(ls snip--*.tar.gz 2>/dev/null | head -1)
if [ -z "$BOTTLE_FILE" ]; then
    BOTTLE_FILE=$(ls snip-*.tar.gz 2>/dev/null | head -1)
fi

if [ -z "$BOTTLE_FILE" ]; then
    echo "错误: 找不到生成的 bottle 文件"
    exit 1
fi

echo "Bottle 文件: $BOTTLE_FILE"
echo ""
echo "手动上传步骤:"
echo "  1. 打开 https://github.com/clanzhang/homebrew-tap/releases/new"
echo "  2. Tag: $VERSION"
echo "  3. 上传 $BOTTLE_FILE"
echo "  4. 发布 Release"
echo ""
echo "=== 4. 更新 Formula bottle sha256 ==="
SHA=$(shasum -a 256 "$BOTTLE_FILE" | cut -d' ' -f1)
echo "SHA256: $SHA"
echo ""
echo "更新 Formula/snip.rb 中的 bottle sha256:"
echo "  sed -i '' 's/REPLACE_WITH_BOTTLE_SHA256/$SHA/' Formula/snip.rb"
echo "  git add Formula/snip.rb && git commit -m 'Update bottle sha256' && git push"