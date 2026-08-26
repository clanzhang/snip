# Snip

macOS 剪贴板 & 快捷键诊断工具，用于排查 Command+C / Command+V 不灵的问题。

## 隐私说明

- Snip **默认不记录**按键字符内容（键盘监控需 `--unsafe-chars` 才输出）
- 剪贴板历史功能（`snip clip record`）会把剪贴板**文本内容**保存在本地 `~/Library/Application Support/snip/history/`，**仅本地使用、绝不上传**
- Snip **只在本地运行**，不会上传任何数据
- 使用 `--unsafe-chars` 或 `--content-preview` 时才可能显示敏感内容
- 所有日志默认保存在 `~/Library/Logs/snip/`

> 不想留下剪贴板历史？`snip clip clear` 一键清空，或删除 `~/Library/Application Support/snip/history/` 目录。

## 安装

### 从源码编译

```bash
git clone https://github.com/clanzhang/snip.git
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
| `snip network` | 无 | — |
| `snip cpu` | 无 | — |
| `snip clip` | 无 | — |

## 命令列表

| 命令 | 说明 |
|------|------|
| `snip watch` | 监控剪贴板变化 |
| `snip keys` | 监控全局键盘事件 |
| `snip all` | 同时监控剪贴板 + 键盘（含复制失败检测） |
| `snip battery` | 查看电池电量、健康度、温度 |
| `snip network` | 查看网络状态（Wi-Fi、DNS、连通性） |
| `snip cpu` | 查看 CPU 状态（型号、负载、使用率、Top 进程） |
| `snip clip` | 剪贴板历史管理（增删改查） |
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

## 剪贴板历史管理（snip clip）

类似 Maccy/Clipy 的剪贴板管理器：复制的内容自动入库，支持增删改查。

```bash
snip clip                     # 显示最近 20 条
snip clip list                # 列出全部（--search 关键词 / --limit N / --json / --pinned）
snip clip show <id>           # 查看完整内容并复制到剪贴板（--no-copy 只看不复制）
snip clip add "文本"           # 写入剪贴板并入库
snip clip edit <id> "新文本"   # 修改内容，同步写入剪贴板
snip clip pin <id>            # 置顶（不受上限裁剪影响）
snip clip unpin <id>          # 取消置顶
snip clip delete <id>         # 删除一条
snip clip clear               # 清空全部（默认需确认，--yes/-y 跳过）
snip clip record              # 监控模式：复制自动入库
snip clip record --daemon     # 后台常驻：随时复制自动记录（日志 ~/Library/Logs/snip/clipd.log）
snip clip stop                # 停止后台记录
snip clip status              # 查看后台记录状态
snip clip autostart on/off    # 开机自启（LaunchAgent）
```

- 历史默认保留最近 **500 条**（`record --max` 可调），置顶条目不受裁剪影响
- 相邻相同内容自动去重，只更新时间
- 图片/文件只记录元数据，不保存内容
- 数据位置：`~/Library/Application Support/snip/history/`（每条一个 `.txt` + `index.json`）

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

### 6. 网络诊断

```bash
snip network
```

检查 Wi-Fi、DNS、公网 IP 和互联网连通性。Universal Clipboard（通用剪贴板）依赖网络，如果网络不通，跨设备剪贴板同步会失效。

```bash
snip network --watch    # 持续监控网络状态
snip network --json     # JSON 输出
```

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
| v0.1.19 | 2026-08-26 | 修复 `record --daemon` 后台启动失败（argv[0] 为裸名时找不到可执行文件） |
| v0.1.18 | 2026-08-26 | 剪贴板记录后台守护：`record --daemon` / `stop` / `status` / `autostart` |
| v0.1.17 | 2026-08-26 | 剪贴板历史管理：`snip clip` 增删改查、置顶、去重、自动入库 |
| v0.1.13 | 2026-08-25 | 热点检测：iPhone USB / 蓝牙热点识别，接口名动态查找 |
| v0.1.12 | 2026-08-25 | 修复 Wi-Fi 接口名硬编码 en0，动态检测 |
| v0.1.11 | 2026-08-25 | 网络诊断：Wi-Fi、DNS、公网 IP、连通性检测 |
| v0.1.10 | 2026-08-24 | 低电量提醒：`--warn` 发送 macOS 通知 |
| v0.1.9 | 2026-08-24 | 修复电池健康度 0% 和充放电状态误判 |
| v0.1.8 | 2026-08-24 | 电池监控：电量、健康度、温度、循环次数 |
| v0.1.7 | 2026-08-24 | Formula 安装时运行 swift test，bottle 发布脚本 |
| v0.1.6 | 2026-08-24 | 18 个单元测试，GitHub Actions CI，bottle 支持，report 增强 |
| v0.1.5 | 2026-08-24 | 添加版本历史到 README |
| v0.1.4 | 2026-08-23 | 应用过滤、macOS 通知、颜色主题、延迟测试、远程诊断服务器、快捷键冲突检测 |
| v0.1.3 | 2026-08-23 | 三层输出格式化（plain/verbose/json）+ CopyFailureDetector |
| v0.1.2 | 2026-08-23 | 移除帮助示例 |
| v0.1.1 | 2026-08-23 | 修复 Package.swift 测试目标 |
| v0.1.0 | 2026-08-23 | 初始版本：watch / keys / all / doctor / test / stats / report |

## License

[MIT](https://github.com/clanzhang/snip/blob/main/LICENSE)
