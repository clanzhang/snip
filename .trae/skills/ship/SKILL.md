---
name: "ship"
description: "snip 项目专用：每次代码改动完成后自动 commit → push → tag → 更新 Homebrew Formula。仅在 snip 项目中生效。"
---

# Ship — 自动发布到 Homebrew

仅用于 `snip` 项目。每次完成代码修改（新功能/修 bug）后，自动执行完整发布流程。

## 触发条件

用户说以下任意关键词时触发：
- `自动commit`、`commit 自动`、`自动提交`
- `发布`、`ship`、`发版`
- `更新 homebrew`、`brew 更新`
- 或任何代码改动完成后的自然结束

## 流程

### 第 1 步：提交到本地仓库

```bash
cd /Users/wzt/Desktop/clan/i/clipdoctor
git add <所有改动的文件>
git commit -m "<简洁描述改动>"
```

如果工作区干净，跳过后续步骤，直接告知用户。

### 第 2 步：推送到 GitHub

```bash
git push origin main
```

### 第 3 步：自动 bump 版本号

当前版本号规则：`v0.1.<patch>`，每次发版 patch +1。

查看最新 tag：
```bash
git tag --sort=-v:refname | head -1
```

比如当前是 `v0.1.3`，新版本就是 `v0.1.4`。

### 第 4 步：打 tag 并推送

```bash
git tag -a v0.1.<N> -m "v0.1.<N>: <改动描述>"
git push origin v0.1.<N>
```

### 第 5 步：更新 Homebrew Formula

```bash
# 更新 url 版本号
cd /opt/homebrew/Library/Taps/clanzhang/homebrew-tap
sed -i '' 's/v0\.1\.[0-9]*/v0.1.<N>/g' Formula/snip.rb

# 计算新 sha256
SHA=$(curl -sL https://github.com/clanzhang/snip/archive/refs/tags/v0.1.<N>.tar.gz | shasum -a 256 | cut -d' ' -f1)

# 替换 sha256
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA\"/" Formula/snip.rb

# 提交并推送 homebrew-tap
git add Formula/snip.rb
git commit -m "snip: bump to v0.1.<N>"
git push
```

### 第 6 步：升级本地安装

```bash
brew upgrade snip
```

## 用户提示

完成所有步骤后，告知用户：
- 新版本号
- commit hash
- 提醒用户在终端执行 `brew upgrade snip`（如果第 6 步在 sandbox 中无法执行）

## 规则

- 只在 snip 项目中有实际代码改动时触发
- 纯文档/样式/格式化改动也发版
- 每次发版 patch +1
- 如果 GitHub push 失败（比如没网络），告知用户手动执行
- 如果 homebrew-tap 目录不存在，创建 `/tmp/homebrew-tap` 并 clone