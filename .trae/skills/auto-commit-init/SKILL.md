---
name: "auto-commit-init"
description: "每次任务完成后自动提交 git。先检查仓库是否初始化，未初始化则自动 git init。Invoke after every task that modifies files."
---

# Auto Commit Init

每次完成代码修改任务后，自动执行 git 提交流程。

## 流程

### 1. 检查仓库是否初始化
```bash
git rev-parse --git-dir 2>/dev/null
```
如果返回错误（未初始化），则执行：
```bash
git init
```

### 2. 创建 .gitignore（如果不存在）
确保 `.gitignore` 存在，至少包含：
```
.build/
.DS_Store
```

### 3. 自动提交
每次任务完成后（文件有改动时），执行：
```bash
git add -A
git commit -m "<简要描述本次改动>"
```

## 规则
- 只在有实际文件改动时才提交，工作区干净则跳过
- 提交信息用中文，简洁描述改动内容
- 不自动 push，除非用户明确要求
- 如果有未跟踪的大文件或二进制文件，提醒用户确认是否需要加入 .gitignore