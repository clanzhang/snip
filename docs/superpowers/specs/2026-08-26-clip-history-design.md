# Snip 剪贴板历史管理（`snip clip`）设计文档

日期：2026-08-26
状态：已确认

## 1. 背景与目标

Snip 目前是 macOS 剪贴板 & 快捷键诊断工具（watch/keys/all 等命令只监控和输出事件，不保存剪贴板内容）。本次新增「剪贴板历史管理」子系统：类似 Maccy/Clipy 的剪贴板管理器，监控复制操作并把文本内容入库，支持增删改查与置顶。

**增**：监控复制自动入库；`snip clip add` 手动新增
**查**：`snip clip list` / `show` / 无参数快速浏览
**改**：`snip clip edit` 修改内容；`pin`/`unpin` 调整置顶状态
**删**：`snip clip delete` / `clear` 清空

## 2. 命令接口

```
snip clip                  # 显示最近 20 条（快速浏览）
snip clip list             # 列出全部（--search 关键词 / --limit N / --json / --pinned）
snip clip show <id>        # 查看完整内容，并复制到剪贴板（--no-copy 只看不复制）
snip clip add "文本"        # 写入剪贴板并入库
snip clip edit <id> "新文本" # 修改内容，同步写入剪贴板
snip clip pin <id>         # 置顶
snip clip unpin <id>       # 取消置顶
snip clip delete <id>      # 删除一条
snip clip clear            # 清空全部；默认弹出确认 "Clear all N items? [y/N]"（--yes/-y 跳过确认）
snip clip record           # 监控模式：复制自动入库（--interval 可调默认 0.3s，--max 可调上限默认 500）
```

- 顶层 `snip -h` 帮助文本补充 `clip` 命令说明。
- 现有 `snip watch` 保持纯诊断监控不变，不写入历史。`snip clip record` 是唯一自动入库入口。

## 3. 存储设计

目录：`~/Library/Application Support/snip/history/`

- 每条记录一个内容文件：`<id>.txt`（完整文本，UTF-8）
- 索引文件：`index.json`

`index.json` 结构（数组，按时间倒序）：

```json
[
  {
    "id": "20260826-153000-abc123",
    "createdAt": "2026-08-26T15:30:00Z",
    "updatedAt": "2026-08-26T15:30:00Z",
    "appName": "Safari",
    "bundleId": "com.apple.Safari",
    "type": "text",              // text | image | file（非文本只记元数据）
    "pinned": false,
    "preview": "前 80 字符……"
  }
]
```

- `list` / 无参数浏览只读索引（preview 字段，快）
- `show` / `edit` 读取或写入 `<id>.txt` 全文
- 删除时同时移除 txt 文件与索引条目
- id 生成：时间戳 + 随机后缀，保证唯一

## 4. 行为规则

- **去重**：相邻相同文本只更新时间戳与来源应用，不新增条目（类 Maccy 默认行为）
- **上限**：默认保留最近 500 条（非置顶），超出自动删除最旧的；`record` 支持 `--max` 调整
- **置顶**：pinned 条目不受上限裁剪影响，排序时永远排在前面
- **图片/文件**：只记录元数据（类型、来源应用、时间、preview 留空或类型名），不存内容；`add` 仅接受文本
- **show 复制**：默认把内容写回系统剪贴板（这是剪贴板管理器的核心用法）；`--no-copy` 跳过
- **edit 同步**：修改内容后同步写入系统剪贴板
- **clear 确认**：默认交互式确认 `Clear all N items? [y/N]`，输入 y/Y 才执行；`--yes`/`-y` 跳过确认
- **隐私**：剪贴板文本仅保存在本地 `~/Library/Application Support/snip/history/`，不上传；README 隐私声明相应更新（默认记录剪贴板文本，但仅本地）

## 5. 实现结构

| 文件 | 职责 |
|------|------|
| `Sources/Snip/HistoryStore.swift`（新） | 存储层：增删改查、索引读写、去重、上限裁剪、pin 排序、原子写入 |
| `Sources/Snip/ClipCommand.swift`（新） | `snip clip` 各子命令执行逻辑（列表渲染、确认提示、剪贴板读写） |
| `Sources/Snip/SnipCommand.swift` | 增加 `clip(ClipOptions)` 命令解析（子命令 + 参数） |
| `Sources/Snip/CLI.swift` | 分发 `clip` 命令；帮助文本补充 |
| `Sources/Snip/main.swift` | 增加 `.clip` 分支 |
| `Tests/SnipTests/HistoryStoreTests.swift`（新） | 存储层单元测试 |
| `README.md` | 命令列表、隐私声明更新 |

## 6. 测试计划

HistoryStoreTests（用临时目录，不污染真实数据）：

- 增：add 写入 txt + 索引；相邻重复去重；上限裁剪（非置顶被删、置顶保留）
- 查：list 排序（置顶优先、时间倒序）；search 关键词过滤；limit 截断
- 改：edit 更新内容与 updatedAt；pin/unpin 状态与排序
- 删：delete 移除 txt 与索引；clear 清空目录
- 索引损坏/缺失时的容错（重建空索引）

## 7. 边界与错误处理

- 目录不存在 → 自动创建
- 索引文件损坏 → 备份为 `index.json.bak` 并以空索引启动
- id 不存在 → 报错 `条目不存在: <id>`，退出码 1
- 空文本 add → 报错提示
- 剪贴板写入失败 → 打印错误提示，但记录仍正常入库（历史数据不因剪贴板失败而丢失）

## 8. 明确不做（YAGNI）

- 图片/文件内容存储（只记元数据）
- 模糊搜索 / 正则搜索（仅子串匹配）
- 历史跨设备同步
- GUI / 菜单栏应用
