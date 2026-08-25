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
          battery    查看电池状态
          network    查看网络状态
          cpu        查看 CPU 状态
          doctor     系统诊断
          test       功能测试
          stats      查看统计
          report     生成诊断报告
          server     启动 HTTP 诊断服务器

        通用参数:
          --json     JSON Lines 输出
          --verbose  详细技术字段输出
          --log      写入日志文件
          --theme    颜色主题 (light/dark/none)
          --ignore   忽略指定应用 (逗号分隔)
          --only     只监控指定应用 (逗号分隔)
          --help     查看帮助
          --version  查看版本

        """)
    }

    func printVersion() {
        print("snip v0.1.16")
    }

    // MARK: - 辅助

    private func makeFormatter(json: Bool, verbose: Bool, theme: String) -> EventFormatter {
        let mode: OutputMode = json ? .json : (verbose ? .verbose : .plain)
        let t: ColorTheme
        switch theme {
        case "dark": t = .dark
        case "none": t = .none
        default: t = .light
        }
        return EventFormatter(mode: mode, theme: t)
    }

    private func makeFilter(ignore: String?, only: String?) -> AppFilter {
        AppFilter(only: AppFilter.parse(only), ignore: AppFilter.parse(ignore))
    }

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

    // MARK: - watch

    func runWatch(opts: WatchOptions) {
        let formatter = makeFormatter(json: opts.json, verbose: opts.verbose, theme: opts.theme)
        let logger = opts.log ? Logger() : nil
        let filter = makeFilter(ignore: opts.ignore, only: opts.only)
        let watcher = ClipboardWatcher(interval: opts.interval, contentPreview: opts.contentPreview)

        watcher.onChange = { event in
            guard filter.shouldOutput(appName: event.appName, bundleId: event.bundleId) else { return }
            let line = formatter.clipboardEvent(event)
            output(line, logger: logger)
        }

        print("剪贴板监控已启动（Ctrl+C 退出）")
        watcher.start()
        runApp()
    }

    // MARK: - keys

    func runKeys(opts: KeysOptions) {
        guard checkPermission() else { return }

        let formatter = makeFormatter(json: opts.json, verbose: opts.verbose, theme: opts.theme)
        let logger = opts.log ? Logger() : nil
        let filter = makeFilter(ignore: opts.ignore, only: opts.only)

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
            guard filter.shouldOutput(appName: event.appName, bundleId: event.bundleId) else { return }
            let line = formatter.keyboardEvent(event)
            output(line, logger: logger)
        }

        print("键盘监控已启动（Ctrl+C 退出）")
        watcher.start()
        runApp()
    }

    // MARK: - all

    func runAll(opts: AllOptions) {
        guard checkPermission() else { return }

        let formatter = makeFormatter(json: opts.json, verbose: opts.verbose, theme: opts.theme)
        let logger = opts.log ? Logger() : nil
        let filter = makeFilter(ignore: opts.ignore, only: opts.only)
        let notifier = opts.notify ? Notifier() : nil
        let stats = FailureStats()
        let failureDetector = CopyFailureDetector(timeoutMs: 800)

        // 剪贴板
        let cb = ClipboardWatcher(interval: opts.interval, contentPreview: opts.contentPreview)
        cb.onChange = { event in
            guard filter.shouldOutput(appName: event.appName, bundleId: event.bundleId) else { return }
            let line = formatter.clipboardEvent(event)
            output(line, logger: logger)
            stats.recordClipboard(type: event.types.first ?? "unknown")
        }

        // 键盘
        let kb = KeyboardWatcher(combos: KeyboardWatcher.defaultCombos, allKeys: false, unsafeChars: false)
        kb.onEvent = { event in
            guard filter.shouldOutput(appName: event.appName, bundleId: event.bundleId) else { return }
            let line = formatter.keyboardEvent(event)
            output(line, logger: logger)

            if event.combo == "cmd+c" && event.type == .keyDown {
                let app = AppInfo(name: event.appName, bundleId: event.bundleId, pid: event.pid)
                failureDetector.onCopyPressed(app: app)
            }
        }

        failureDetector.onFailure = { failure in
            let line = formatter.copyFailureEvent(failure)
            output(line, logger: logger)
            stats.recordFailure(app: failure.app)
            notifier?.copyFailure(app: failure.app)
        }

        failureDetector.onSuccess = { success in
            let line = formatter.copySuccessEvent(success)
            output(line, logger: logger)
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
        } else if opts.latency {
            testLatency()
        } else {
            print("请指定测试项:")
            print("  snip test --clipboard   剪贴板读写测试")
            print("  snip test --keys        快捷键检测测试")
            print("  snip test --latency     pbcopy/pbpaste 延迟测试")
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

    /// pbcopy/pbpaste 延迟测试
    private func testLatency() {
        print("测试 pbcopy/pbpaste 延迟...\n")
        let iterations = 10
        let testStr = "latency-test-\(Int(Date().timeIntervalSince1970))"
        var times: [Double] = []

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()

            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = ["-c", "echo -n '\(testStr)' | pbcopy && pbpaste"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.launch()
            process.waitUntilExit()

            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            times.append(elapsed)
        }

        let avg = times.reduce(0, +) / Double(iterations)
        let min = times.min() ?? 0
        let max = times.max() ?? 0

        print("测试次数: \(iterations)")
        print("平均延迟: \(String(format: "%.2f", avg)) ms")
        print("最小延迟: \(String(format: "%.2f", min)) ms")
        print("最大延迟: \(String(format: "%.2f", max)) ms")

        if avg < 10 {
            print("结论：pbcopy/pbpaste 延迟正常")
        } else if avg < 50 {
            print("结论：pbcopy/pbpaste 延迟偏高")
        } else {
            print("结论：pbcopy/pbpaste 延迟异常，可能是系统负载或第三方工具影响")
        }
    }

    // MARK: - server

    func runServer(opts: ServerOptions) {
        let srv = Server(port: opts.port)
        srv.run()
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
        let totalCopies = lines.filter { $0.contains("clipboard changed") || $0.contains("剪贴板更新") }.count
        let failures = lines.filter { $0.contains("copy timeout") || $0.contains("没变化") }.count

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

    // MARK: - battery

    func runBattery(opts: BatteryOptions) {
        if opts.watch {
            let watcher = BatteryWatcher(interval: opts.interval, warnThreshold: opts.warnThreshold)
            watcher.onUpdate = { info in
                if opts.json {
                    self.printBatteryJSON(info)
                } else {
                    print(info.summary)
                }
            }
            watcher.onLowBattery = { info in
                let msg = "⚠️ 电量仅剩 \(info.percentage)%，该充电啦！"
                print(msg)
                Notifier().notify(title: "电池电量低", subtitle: msg, body: "剩余 \(info.percentage)%，请连接电源")
            }
            if opts.warnThreshold != nil {
                print("电池监控已启动（低电量提醒 \(opts.warnThreshold!)%）（Ctrl+C 退出）")
            } else {
                print("电池监控已启动（Ctrl+C 退出）")
            }
            watcher.start()
            runApp()
        } else {
            guard let info = BatteryWatcher.fetch() else {
                print("❌ 无法获取电池信息（仅支持 MacBook）")
                return
            }
            if opts.json {
                printBatteryJSON(info)
            } else {
                print(info.summary)
            }
        }
    }

    private func printBatteryJSON(_ info: BatteryInfo) {
        let dict: [String: Any] = [
            "percentage": info.percentage,
            "status": info.statusText,
            "charging": info.isCharging,
            "plugged_in": info.isPluggedIn,
            "current_capacity": info.currentCapacity,
            "max_capacity": info.maxCapacity,
            "design_capacity": info.designCapacity,
            "cycle_count": info.cycleCount,
            "health_percent": info.healthPercent,
            "time_remaining": info.timeRemaining ?? NSNull(),
            "temperature": info.temperature ?? NSNull()
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    // MARK: - network

    func runNetwork(opts: NetworkOptions) {
        if opts.watch {
            let watcher = NetworkWatcher(interval: opts.interval)
            watcher.onUpdate = { info in
                if opts.json {
                    self.printNetworkJSON(info)
                } else {
                    print(info.summary)
                    print("---")
                }
            }
            print("网络监控已启动（Ctrl+C 退出）")
            watcher.start()
            runApp()
        } else {
            let info = NetworkWatcher.fetch()
            if opts.json {
                printNetworkJSON(info)
            } else {
                print(info.summary)
            }
        }
    }

    private func printNetworkJSON(_ info: NetworkInfo) {
        let dict: [String: Any] = [
            "wifi_ssid": info.wifiSSID ?? NSNull(),
            "wifi_rssi": info.wifiRSSI ?? NSNull(),
            "wifi_channel": info.wifiChannel ?? NSNull(),
            "signal_strength": info.signalStrength,
            "interfaces": info.interfaces.map { iface in
                return [
                    "name": iface.name,
                    "display_name": iface.displayName,
                    "address": iface.address ?? NSNull(),
                    "netmask": iface.netmask ?? NSNull(),
                    "active": iface.isActive
                ] as [String: Any]
            },
            "dns_servers": info.dnsServers,
            "public_ip": info.publicIP ?? NSNull(),
            "connectivity": info.connectivity
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    // MARK: - cpu

    func runCPU(opts: CPUOptions) {
        if opts.watch {
            let watcher = CPUWatcher(interval: opts.interval)
            watcher.onUpdate = { info in
                if opts.json {
                    self.printCPUJSON(info)
                } else {
                    print(info.summary)
                    print("---")
                }
            }
            print("CPU 监控已启动（Ctrl+C 退出）")
            watcher.start()
            runApp()
        } else {
            guard let info = CPUWatcher.fetch() else {
                print("❌ 无法获取 CPU 信息")
                return
            }
            if opts.json {
                printCPUJSON(info)
            } else {
                print(info.summary)
            }
        }
    }

    private func printCPUJSON(_ info: CPUInfo) {
        let dict: [String: Any] = [
            "model": info.modelName,
            "physical_cores": info.physicalCores,
            "logical_cores": info.logicalCores,
            "cpu_user_pct": info.cpuUsage.user,
            "cpu_system_pct": info.cpuUsage.system,
            "cpu_idle_pct": info.cpuUsage.idle,
            "cpu_nice_pct": info.cpuUsage.nice,
            "process_count": info.processCount,
            "load_average_1m": info.loadAverage1,
            "load_average_5m": info.loadAverage5,
            "load_average_15m": info.loadAverage15,
            "top_processes": info.topProcesses.map { ["cpu_pct": $0.cpu, "name": $0.name] }
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
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