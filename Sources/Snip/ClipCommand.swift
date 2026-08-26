import AppKit
import Foundation

// MARK: - 剪贴板历史命令（snip clip）

struct ClipCommand {
    let opts: ClipOptions
    private let store: HistoryStore

    init(opts: ClipOptions) {
        self.opts = opts
        self.store = HistoryStore(maxEntries: opts.max)
    }

    func run() {
        switch opts.action {
        case .help:
            printHelp()
        case .list:
            runList(recentOnly: opts.recentOnly)
        case .show:
            runShow()
        case .add:
            runAdd()
        case .edit:
            runEdit()
        case .pin:
            runPin(pinned: true)
        case .unpin:
            runPin(pinned: false)
        case .delete:
            runDelete()
        case .clear:
            runClear()
        case .record:
            runRecord()
        }
    }

    func printHelp() {
        print("""
        snip clip — 剪贴板历史管理

        用法:
          snip clip                    显示最近 20 条
          snip clip list               列出全部（--search 关键词 / --limit N / --json / --pinned）
          snip clip show <id>          查看完整内容并复制到剪贴板（--no-copy 只看不复制）
          snip clip add "文本"          写入剪贴板并入库
          snip clip edit <id> "新文本"  修改内容，同步写入剪贴板
          snip clip pin <id>           置顶
          snip clip unpin <id>         取消置顶
          snip clip delete <id>        删除一条
          snip clip clear              清空全部（默认需确认，--yes/-y 跳过）
          snip clip record             监控模式：复制自动入库（--interval 可调，--max 调整上限）

        历史存储位置: \(HistoryStore.defaultDirectory().path)
        上限: 默认 500 条（--max 调整），置顶条目不受裁剪影响

        """)
    }

    // MARK: - 查

    private func runList(recentOnly: Bool) {
        let limit: Int? = recentOnly ? 20 : opts.limit
        let entries = store.list(search: opts.search, limit: limit, pinnedOnly: opts.pinnedOnly)

        if opts.json {
            for e in entries { print(jsonLine(e)) }
            return
        }
        if entries.isEmpty {
            print("暂无历史记录。")
            return
        }
        if recentOnly {
            let total = store.count
            print("最近 \(entries.count) 条（共 \(total) 条，snip clip list 查看全部）")
        } else {
            print("共 \(entries.count) 条记录：")
        }
        print("---")
        for (i, e) in entries.enumerated() {
            let pin = e.pinned ? "📌 " : "   "
            let time = formatTime(e.updatedAt)
            let app = (e.appName.isEmpty ? "—" : e.appName)
                .padding(toLength: 18, withPad: " ", startingAt: 0)
            print("\(String(format: "%3d", i + 1)) \(pin)\(time)  \(app) \(e.preview)")
        }
    }

    private func runShow() {
        guard let id = opts.id else {
            fputs("用法: snip clip show <id> [--no-copy] [--json]\n", stderr)
            exit(1)
        }
        guard let entry = store.get(id: id) else {
            fputs("❌ 条目不存在: \(id)\n", stderr)
            exit(1)
        }
        guard entry.type == .text, let content = store.content(id: id) else {
            print("类型: \(entry.type.rawValue)  来源: \(entry.appName)  时间: \(formatTime(entry.updatedAt))（无文本内容）")
            return
        }

        if opts.json {
            var dict: [String: Any] = [
                "id": entry.id,
                "app": entry.appName,
                "bundle_id": entry.bundleId,
                "type": entry.type.rawValue,
                "pinned": entry.pinned,
                "created_at": Int(entry.createdAt.timeIntervalSince1970),
                "updated_at": Int(entry.updatedAt.timeIntervalSince1970),
                "content": content
            ]
            if entry.pinned { dict["pinned"] = true }
            print(json(from: dict))
            return
        }

        print(content)
        if !opts.noCopy {
            let pb = NSPasteboard.general
            pb.clearContents()
            if pb.setString(content, forType: .string) {
                print("→ 已复制到剪贴板")
            } else {
                fputs("⚠️ 剪贴板写入失败\n", stderr)
            }
        }
    }

    // MARK: - 增

    private func runAdd() {
        guard let text = opts.text, !text.isEmpty else {
            fputs("用法: snip clip add \"文本\"\n", stderr)
            exit(1)
        }
        let app = FrontAppDetector.current()
        let entry = store.add(text: text, appName: app.name, bundleId: app.bundleId)

        let pb = NSPasteboard.general
        pb.clearContents()
        if pb.setString(text, forType: .string) {
            print("✅ 已写入剪贴板并入库: \(entry.id)")
        } else {
            fputs("⚠️ 剪贴板写入失败，记录已保存\n", stderr)
        }
    }

    // MARK: - 改

    private func runEdit() {
        guard let id = opts.id, let text = opts.text, !text.isEmpty else {
            fputs("用法: snip clip edit <id> \"新文本\"\n", stderr)
            exit(1)
        }
        guard store.update(id: id, text: text) != nil else {
            fputs("❌ 条目不存在: \(id)\n", stderr)
            exit(1)
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        if pb.setString(text, forType: .string) {
            print("✅ 已更新并复制到剪贴板: \(id)")
        } else {
            fputs("⚠️ 剪贴板写入失败，记录已更新\n", stderr)
        }
    }

    private func runPin(pinned: Bool) {
        guard let id = opts.id else {
            fputs("用法: snip clip \(pinned ? "pin" : "unpin") <id>\n", stderr)
            exit(1)
        }
        guard let entry = store.setPinned(id: id, pinned: pinned) else {
            fputs("❌ 条目不存在: \(id)\n", stderr)
            exit(1)
        }
        print(pinned ? "📌 已置顶: \(entry.preview)" : "已取消置顶: \(entry.preview)")
    }

    // MARK: - 删

    private func runDelete() {
        guard let id = opts.id else {
            fputs("用法: snip clip delete <id>\n", stderr)
            exit(1)
        }
        guard store.delete(id: id) else {
            fputs("❌ 条目不存在: \(id)\n", stderr)
            exit(1)
        }
        print("🗑 已删除: \(id)")
    }

    private func runClear() {
        let n = store.count
        guard n > 0 else {
            print("暂无历史记录。")
            return
        }
        if !opts.yes {
            print("Clear all \(n) items? [y/N] ", terminator: "")
            fflush(stdout)
            guard let line = readLine(), line.lowercased() == "y" else {
                print("已取消。")
                return
            }
        }
        let removed = store.clear()
        print("已清空 \(removed) 条记录。")
    }

    // MARK: - record（监控入库）

    private func runRecord() {
        signal(SIGINT) { _ in
            print("\n已停止。")
            exit(0)
        }
        let watcher = ClipboardWatcher(interval: opts.interval, contentPreview: 0)
        let pb = NSPasteboard.general

        watcher.onChange = { event in
            if event.isText, let text = pb.string(forType: .string), !text.isEmpty {
                let entry = store.add(text: text, appName: event.appName, bundleId: event.bundleId)
                if opts.json {
                    print(recordJSON(type: "text", entry: entry, app: event.appName))
                } else {
                    print("📋 \(formatTime(entry.updatedAt)) [\(event.appName)] \(entry.preview)")
                }
            } else {
                let type: HistoryType = event.isImage ? .image : .file
                let entry = store.addMetadata(type: type, appName: event.appName, bundleId: event.bundleId)
                if opts.json {
                    print(recordJSON(type: type.rawValue, entry: entry, app: event.appName))
                } else {
                    let icon = type == .image ? "🖼" : "📄"
                    print("\(icon) \(formatTime(entry.updatedAt)) [\(event.appName)] \(entry.preview)")
                }
            }
        }

        print("剪贴板历史记录中（Ctrl+C 退出，上限 \(opts.max) 条）")
        watcher.start()
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.run()
    }

    // MARK: - 输出辅助

    private func formatTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f.string(from: d)
    }

    private func jsonLine(_ e: HistoryEntry) -> String {
        json(from: [
            "id": e.id,
            "app": e.appName,
            "bundle_id": e.bundleId,
            "type": e.type.rawValue,
            "pinned": e.pinned,
            "created_at": Int(e.createdAt.timeIntervalSince1970),
            "updated_at": Int(e.updatedAt.timeIntervalSince1970),
            "preview": e.preview
        ])
    }

    private func recordJSON(type: String, entry: HistoryEntry, app: String) -> String {
        json(from: [
            "event": "clip_recorded",
            "id": entry.id,
            "app": app,
            "type": type,
            "pinned": entry.pinned,
            "time": Int(entry.updatedAt.timeIntervalSince1970),
            "preview": entry.preview
        ])
    }

    private func json(from dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }
}
