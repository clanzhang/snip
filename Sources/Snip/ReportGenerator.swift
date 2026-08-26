import AppKit
import Foundation

/// snip report — 生成诊断报告
struct ReportGenerator {
    func generate(outputPath: String) -> String {
        let expandedPath = (outputPath as NSString).expandingTildeInPath
        let outputURL = URL(fileURLWithPath: expandedPath)

        var report = ""
        report += "Snip 诊断报告\n"
        report += "============\n\n"
        report += "版本: v0.1.17\n"
        report += "生成时间: \(ISO8601DateFormatter().string(from: Date()))\n\n"

        // 系统信息
        let os = ProcessInfo.processInfo.operatingSystemVersion
        report += "macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)\n"
        report += "Model: \(modelName())\n"
        report += "User: \(NSUserName())\n"
        report += "Input Source: \(InputSourceDetector.current())\n\n"

        // 权限
        report += "--- 权限 ---\n"
        report += "Input Monitoring: \(PermissionChecker.hasInputMonitoring() ? "OK" : "Missing")\n"
        report += "Accessibility: \(AXIsProcessTrusted() ? "OK" : "Missing")\n\n"

        // 剪贴板测试
        report += "--- 剪贴板测试 ---\n"
        report += "pbcopy/pbpaste: \(testPasteboard() ? "OK" : "FAIL")\n\n"

        // 检测工具
        report += "--- 运行中的工具 ---\n"
        let tools = detectRunningTools()
        if tools.isEmpty {
            report += "None\n"
        } else {
            for t in tools { report += "- \(t)\n" }
        }

        // 系统硬件摘要
        report += "\n--- 硬件摘要 ---\n"
        report += systemProfilerSummary()
        report += "\n"

        // 最近日志摘要
        report += "\n--- 最近日志摘要 ---\n"
        let logPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/snip/snip.log")
        if let content = try? String(contentsOf: logPath, encoding: .utf8) {
            let lines = content.split(separator: "\n").suffix(50)
            for line in lines { report += "\(line)\n" }
        } else {
            report += "暂无日志。\n"
        }

        // 建议
        report += "\n--- 建议 ---\n"
        if !tools.isEmpty {
            report += "检测到剪贴板或快捷键工具，建议临时退出后重新测试。\n"
        }
        if !PermissionChecker.hasInputMonitoring() {
            report += "需要授予终端输入监控权限才能使用 snip keys / snip all。\n"
        }
        report += "\n该报告可以安全提交给 Apple Feedback Assistant。\n"

        // 写入
        try? report.write(to: outputURL, atomically: true, encoding: .utf8)
        return expandedPath
    }

    private func modelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func testPasteboard() -> Bool {
        let testStr = "snip-report-\(Int(Date().timeIntervalSince1970))"
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
            "com.raycast.macos", "com.alfredapp.alfred", "com.runningwithcrayons.Alfred",
            "com.hegenberg.BetterTouchTool", "com.keyboardmaestro.Keyboard-Maestro",
            "org.pqrs.Karabiner-Elements", "com.wiheads.paste", "com.maccy.maccy",
            "com.pilotmoon.copyclip", "com.cleanshot.CleanShot", "com.surteesstudios.Bartender",
        ]
        var found: [String] = []
        for app in NSWorkspace.shared.runningApplications {
            if let bid = app.bundleIdentifier, known.contains(bid) {
                found.append(app.localizedName ?? bid)
            }
        }
        return found
    }

    /// 运行 system_profiler 获取硬件摘要
    private func systemProfilerSummary() -> String {
        let process = Process()
        process.launchPath = "/usr/sbin/system_profiler"
        process.arguments = ["SPHardwareDataType", "SPSoftwareDataType", "-detailLevel", "mini"]
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        process.launch()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? "获取硬件信息失败"
    }
}