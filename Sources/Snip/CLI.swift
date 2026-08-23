import AppKit
import Foundation

/// 命令行接口：帮助、版本、各命令的执行
struct CLI {
    // MARK: - 帮助 & 版本

    func printHelp() {
        print("""
        snip — macOS 剪贴板 & 快捷键诊断工具

        用法:
          snip <command> [options]

        命令:
          watch      监控剪贴板变化
          keys       监控全局键盘事件
          all        同时监控剪贴板 + 键盘（含复制失败检测）
          doctor     系统诊断
          test       功能测试
          stats      查看统计
          report     生成诊断报告

        通用参数:
          --json     JSON Lines 输出
          --log      写入日志文件
          --help     查看帮助
          --version  查看版本

        示例:
          snip watch
          snip watch --json --log
          snip keys
          snip keys --all-keys --json
          snip all
          snip doctor
          snip test --clipboard
          snip test --keys
          snip stats
          snip report
        """)
    }

    func printVersion() {
        print("snip v1.0.0")
    }

    // MARK: - watch

    func runWatch(opts: WatchOptions) {
        let formatter = EventFormatter()
        let logger = opts.log ? Logger() : nil
        let watcher = ClipboardWatcher(interval: opts.interval, contentPreview: opts.contentPreview)

        watcher.onChange = { event in
            let line = formatter.clipboardEvent(event, json: opts.json)
            output(line, logger: logger)
        }

        print("剪贴板监控已启动（Ctrl+C 退出）")
        watcher.start()
        runApp()
    }

    // MARK: - keys

    func runKeys(opts: KeysOptions) {
        guard checkPermission() else { return }

        let formatter = EventFormatter()
        let logger = opts.log ? Logger() : nil

        let combos: Set<HotKey>?
        if opts.allKeys {
            combos = nil
        } else if let keys = opts.customKeys {
            combos = KeyboardWatcher.parseComboString(keys)
        } else {
            combos = KeyboardWatcher.defaultCombos
        }

        if opts.unsafeChars {
            print("⚠️ 警告：--unsafe-chars 会记录按键字符，可能泄露密码、聊天记录和敏感信息。仅建议在本地调试时使用。")
        }

        let watcher = KeyboardWatcher(combos: combos, allKeys: opts.allKeys, unsafeChars: opts.unsafeChars)

        watcher.onEvent = { event in
            let line = formatter.keyboardEvent(event, json: opts.json)
            output(line, logger: logger)
        }

        print("键盘监控已启动（Ctrl+C 退出）")
        watcher.start()
        runApp()
    }

    // MARK: - all

    func runAll(opts: AllOptions) {
        guard checkPermission() else { return }

        let formatter = EventFormatter()
        let logger = opts.log ? Logger() : nil
        let stats = FailureStats()

        // 剪贴板
        let cb = ClipboardWatcher(interval: opts.interval, contentPreview: opts.contentPreview)
        cb.onChange = { event in
            let line = formatter.clipboardEvent(event, json: opts.json)
            output(line, logger: logger)
            stats.recordClipboard(type: event.types.first ?? "unknown")
        }

        // 键盘
        let kb = KeyboardWatcher(combos: KeyboardWatcher.defaultCombos, allKeys: false, unsafeChars: false)
        kb.onEvent = { event in
            let line = formatter.keyboardEvent(event, json: opts.json)
            output(line, logger: logger)

            // 复制失败检测
            if event.combo == "cmd+c" && event.type == .keyDown {
                let before = NSPasteboard.general.changeCount
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(800)) {
                    let after = NSPasteboard.general.changeCount
                    if before == after {
                        let failure = CopyFailure(
                            timestamp: Date(),
                            combo: "cmd+c",
                            app: event.appName,
                            bundleId: event.bundleId,
                            pid: event.pid,
                            previousChangeCount: before,
                            currentChangeCount: after,
                            timeoutMs: 800
                        )
                        let line = formatter.copyFailureEvent(failure, json: opts.json)
                        output(line, logger: logger)
                        stats.recordFailure(app: failure.app)
                    }
                }
            }
        }

        cb.start()
        kb.start()
        print("联合监控已启动（Ctrl+C 退出）")
        runApp()
    }

    // MARK: - doctor

    func runDoctor() {
        let d = Diagnosis()
        d.run()
    }

    // MARK: - test

    func runTest(opts: TestOptions) {
        if opts.clipboard {
            testClipboard()
        } else if opts.keys {
            testKeys()
        } else {
            print("请指定测试项: --clipboard 或 --keys")
            print("用法: snip test --clipboard")
            print("      snip test --keys")
        }
    }

    private func testClipboard() {
        let testStr = "snip-test-\(Int(Date().timeIntervalSince1970))"
        let pb = NSPasteboard.general

        pb.clearContents()
        let wrote = pb.setString(testStr, forType: .string)
        print(wrote ? "✅ 剪贴板写入成功" : "❌ 剪贴板写入失败")

        let read = pb.string(forType: .string)
        if read != nil {
            print("✅ 剪贴板读取成功")
        } else {
            print("❌ 剪贴板读取失败")
        }

        if read == testStr {
            print("✅ 内容一致")
            print("结论：剪贴板底层正常")
        } else {
            print("结论：剪贴板读取异常")
        }
    }

    private func testKeys() {
        guard checkPermission() else { return }

        print("请在 5 秒内按下 Command+C ...")
        var detected = false

        let watcher = KeyboardWatcher(combos: KeyboardWatcher.parseComboString("cmd+c"), allKeys: false, unsafeChars: false)
        watcher.onEvent = { event in
            if event.combo == "cmd+c", event.type == .keyDown {
                detected = true
            }
        }
        watcher.start()

        let deadline = DispatchTime.now() + .seconds(5)
        while DispatchTime.now() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            if detected { break }
        }
        watcher.stop()

        if detected {
            print("✅ 收到 cmd+c")
        } else {
            print("❌ 未收到 cmd+c")
            print("可能原因：")
            print("1. 没有输入监控权限")
            print("2. 快捷键被其他工具拦截")
            print("3. 当前终端未被授权")
            print("4. 键盘或输入法异常")
        }
        exit(0)
    }

    // MARK: - stats

    func runStats() {
        let logPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/snip/snip.log")

        guard FileManager.default.fileExists(atPath: logPath.path),
              let content = try? String(contentsOf: logPath, encoding: .utf8) else {
            print("暂无日志数据。")
            return
        }

        let lines = content.split(separator: "\n")
        let totalCopies = lines.filter { $0.contains("clipboard changed") }.count
        let failures = lines.filter { $0.contains("copy timeout") }.count

        print("最近统计：")
        print("复制事件: \(totalCopies)")
        print("可疑失败: \(failures)")
        if totalCopies > 0 {
            let rate = Double(failures) / Double(totalCopies) * 100
            print("失败率: \(String(format: "%.1f", rate))%")
        }
    }

    // MARK: - report

    func runReport(opts: ReportOptions) {
        let report = ReportGenerator()
        let path = report.generate(outputPath: opts.output)
        print("报告已生成: \(path)")
    }

    // MARK: - 辅助

    private func checkPermission() -> Bool {
        if !PermissionChecker.hasInputMonitoring() {
            fputs("\(PermissionChecker.guide())\n", stderr)
            exit(1)
        }
        return true
    }

    private func output(_ line: String, logger: Logger?) {
        if let log = logger {
            var l = log
            l.log(line)
        } else {
            print(line)
        }
    }

    private func runApp() {
        signal(SIGINT) { _ in
            print("\n已停止。")
            exit(0)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

// MARK: - 内存统计

class FailureStats {
    var totalClipboard = 0
    var totalFailures = 0
    var failuresByApp: [String: Int] = [:]
    var typesByClipboard: [String: Int] = [:]

    func recordClipboard(type: String) {
        totalClipboard += 1
        typesByClipboard[type, default: 0] += 1
    }

    func recordFailure(app: String) {
        totalFailures += 1
        failuresByApp[app, default: 0] += 1
    }
}