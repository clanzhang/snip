import AppKit
import Foundation

/// snip doctor — 系统诊断
struct Diagnosis {
    func run() {
        print("Snip Doctor\n")

        // 1. macOS
        let os = ProcessInfo.processInfo.operatingSystemVersion
        print("macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")

        // 2. 机型
        print("Model: \(modelName())")

        // 3. 用户
        print("User: \(NSUserName())")

        // 4. 安全模式
        let safe = isSafeBoot()
        print("Safe Mode: \(safe ? "YES ⚠️" : "No")")

        // 5. 输入法
        print("Input Source: \(InputSourceDetector.currentName()) (\(InputSourceDetector.current()))")

        // 6. 输入监控
        let im = PermissionChecker.hasInputMonitoring()
        print("Input Monitoring: \(im ? "OK" : "Missing ⚠️")")

        // 7. 辅助功能
        let ax = AXIsProcessTrusted()
        print("Accessibility: \(ax ? "OK" : "Missing")")

        // 8. 剪贴板
        let pbOK = testPasteboard()
        print("Clipboard pbcopy/pbpaste: \(pbOK ? "OK" : "FAIL ⚠️")")

        // 9. 检测常见工具
        let tools = detectRunningTools()
        if tools.isEmpty {
            print("Detected tools: None")
        } else {
            print("Detected tools: \(tools.joined(separator: ", "))")
        }

        // 10. 最近失败
        let recentFails = countRecentFailures()
        print("Recent copy failures: \(recentFails)")

        // 11. 快捷键冲突检测
        let conflicts = detectHotKeyConflicts()
        if conflicts.isEmpty {
            print("Hotkey conflicts: None detected")
        } else {
            print("Hotkey conflicts: \(conflicts.joined(separator: ", ")) ⚠️")
        }

        // 建议
        print("\n建议：")
        var suggestions: [String] = []
        if !im { suggestions.append("请授予终端输入监控权限。") }
        if !tools.isEmpty { suggestions.append("检测到剪贴板或快捷键增强工具，建议临时退出后测试。") }
        if !conflicts.isEmpty { suggestions.append("检测到多个工具可能拦截同一快捷键，建议逐一排查。") }
        if safe { suggestions.append("系统处于安全模式，部分功能可能受限。") }
        if !pbOK { suggestions.append("pbcopy/pbpaste 测试失败，剪贴板底层可能异常。") }
        if suggestions.isEmpty {
            print("未发现明显问题。")
        } else {
            for (i, s) in suggestions.enumerated() {
                print("\(i + 1). \(s)")
            }
        }
    }

    // MARK: - 辅助

    private func modelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func isSafeBoot() -> Bool {
        var sb: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.safeboot", &sb, &size, nil, 0)
        return sb == 1
    }

    private func testPasteboard() -> Bool {
        let testStr = "snip-doctor-\(Int(Date().timeIntervalSince1970))"
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", "echo -n '\(testStr)' | pbcopy && pbpaste"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output == testStr
    }

    private func detectRunningTools() -> [String] {
        let known: [String] = [
            "com.raycast.macos",
            "com.alfredapp.alfred",
            "com.runningwithcrayons.Alfred",
            "com.hegenberg.BetterTouchTool",
            "com.keyboardmaestro.Keyboard-Maestro",
            "org.pqrs.Karabiner-Elements",
            "com.wiheads.paste",
            "com.maccy.maccy",
            "com.pilotmoon.copyclip",
            "com.cleanshot.CleanShot",
            "com.surteesstudios.Bartender",
        ]
        var found: [String] = []
        for app in NSWorkspace.shared.runningApplications {
            if let bid = app.bundleIdentifier, known.contains(bid) {
                found.append(app.localizedName ?? bid)
            }
        }
        return found
    }

    private func detectHotKeyConflicts() -> [String] {
        // 检测同时运行的可能拦截快捷键的工具
        let tools = detectRunningTools()
        let hotkeyTools = tools.filter { t in
            // 已知会拦截全局快捷键的工具
            let bids = [
                "com.raycast.macos", "com.alfredapp.alfred",
                "com.hegenberg.BetterTouchTool", "org.pqrs.Karabiner-Elements",
            ]
            // 通过 process name 匹配
            for bid in bids {
                for app in NSWorkspace.shared.runningApplications {
                    if app.bundleIdentifier == bid { return true }
                }
            }
            return false
        }
        if hotkeyTools.count >= 2 {
            return ["多个快捷键工具同时运行"]
        }
        return []
    }

    private func countRecentFailures() -> Int {
        let logPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/snip/snip.log")
        guard let content = try? String(contentsOf: logPath, encoding: .utf8) else { return 0 }
        let lines = content.split(separator: "\n")
        let cutoff = Date().addingTimeInterval(-600) // 10 分钟
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return lines.filter { line in
            guard line.contains("copy timeout") else { return false }
            let prefix = String(line.prefix(23))
            guard prefix.hasPrefix("["), let ts = fmt.date(from: String(prefix.dropFirst())) else { return false }
            return ts >= cutoff
        }.count
    }
}