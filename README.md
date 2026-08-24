# Snip

macOS 剪贴板 & 快捷键诊断工具，用于排查 Command+C / Command+V 不灵的问题。

## 隐私说明

- Snip **默认不记录**用户输入的文字内容
- Snip **默认不记录**完整剪贴板内容
- Snip **只在本地运行**，不会上传任何数据
- 使用 `--unsafe-chars` 或 `--content-preview` 时才可能显示敏感内容
- 所有日志默认保存在 `~/Library/Logs/snip/`

## 安装

### 从源码编译

```bash
git clone https://github.com/user/snip.git
cd snip
swift build -c release
cp .build/release/snip /usr/local/bin/
```

### 使用 Homebrew

```bash
brew tap clanzhang/tap
brew install snip
```

升级：

```bash
brew upgrade snip
```

卸载：

```bash
brew uninstall snip
brew untap clanzhang/tap
```

## 权限说明

| 功能 | 所需权限 | 如何授权 |
|------|----------|----------|
| `snip watch` | 无 | — |
| `snip doctor` | 无 | — |
| `snip test --clipboard` | 无 | — |
| `snip keys` | 输入监控 | 系统设置 > 隐私与安全性 > 输入监控 |
| `snip all` | 输入监控 | 同上 |
| `snip test --keys` | 输入监控 | 同上 |

## 命令列表

| 命令 | 说明 |
|------|------|
| `snip watch` | 监控剪贴板变化 |
| `snip keys` | 监控全局键盘事件 |
| `snip all` | 同时监控剪贴板 + 键盘（含复制失败检测） |
| `snip doctor` | 系统诊断 |
| `snip test --clipboard` | 测试剪贴板底层 |
| `snip test --keys` | 测试全局快捷键 |
| `snip stats` | 查看统计 |
| `snip report` | 生成诊断报告 |

## 常用参数

| 参数 | 说明 | 适用命令 |
|------|------|----------|
| `--json` | JSON Lines 输出 | watch, keys, all |
| `--log` | 写入日志文件 | watch, keys, all |
| `--interval 0.5` | 轮询间隔（秒） | watch, all |
| `--content-preview 20` | 显示前 20 字符 | watch |
| `--all-keys` | 所有按键元数据 | keys |
| `--unsafe-chars` | 输出按键字符（⚠️ 隐私警告） | keys |
| `--keys "cmd+c,cmd+v"` | 自定义快捷键 | keys |

## 常见排查流程

### 1. 快速诊断

```bash
snip doctor
```

### 2. 检测复制失败

```bash
snip all
```

然后在任何应用中复制粘贴，观察输出。如果出现 `❌ copy timeout`，说明复制失败。

### 3. 测试剪贴板底层

```bash
snip test --clipboard
```

### 4. 测试快捷键

```bash
snip test --keys
```

### 5. 生成报告

```bash
snip report
```

报告默认保存到 `~/Desktop/snip-report.txt`，可以安全提交给 Apple Feedback Assistant。

## 提交 Apple Feedback

1. 运行 `snip report` 生成诊断报告
2. 打开 [Apple Feedback Assistant](https://feedbackassistant.apple.com/)
3. 提交报告时附上 `snip-report.txt`

## 开发

```bash
swift build
swift run snip --help
swift run snip watch
swift run snip keys
swift run snip doctor
swift run snip report
```

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1.4 | 2026-08-23 | 应用过滤、macOS 通知、颜色主题、延迟测试、远程诊断服务器、快捷键冲突检测 |
| v0.1.3 | 2026-08-23 | 三层输出格式化（plain/verbose/json）+ CopyFailureDetector |
| v0.1.2 | 2026-08-23 | 移除帮助示例 |
| v0.1.1 | 2026-08-23 | 修复 Package.swift 测试目标 |
| v0.1.0 | 2026-08-23 | 初始版本：watch / keys / all / doctor / test / stats / report |

## License

MIT