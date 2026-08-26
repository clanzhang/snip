import Foundation

/// 剪贴板记录守护进程管理：后台常驻 record、PID 文件、日志、LaunchAgent 自启
struct ClipDaemon {
    static let label = "com.clanzhang.snip.clipd"

    // MARK: - 路径

    static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("snip", isDirectory: true)
    }

    static var pidFileURL: URL {
        supportDir.appendingPathComponent("clipd.pid")
    }

    static var logFileURL: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/snip")
        return base.appendingPathComponent("clipd.log")
    }

    static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    // MARK: - PID 文件

    static func writePidFile(pid: Int32) {
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        try? "\(pid)".write(to: pidFileURL, atomically: true, encoding: .utf8)
    }

    static func readPid() -> Int32? {
        guard let s = try? String(contentsOf: pidFileURL, encoding: .utf8),
              let pid = Int32(s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return pid
    }

    static func removePidFile() {
        try? FileManager.default.removeItem(at: pidFileURL)
    }

    /// 是否在运行（PID 文件存在且进程存活）
    static func isRunning() -> Bool {
        guard let pid = readPid() else { return false }
        return kill(pid, 0) == 0
    }

    // MARK: - 启动 / 停止

    /// 从父进程启动后台子进程（detach），立即返回
    @discardableResult
    static func startDaemon() -> Bool {
        guard !isRunning() else { return false }

        try? FileManager.default.createDirectory(
            at: logFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        let logHandle = FileHandle(forWritingAtPath: logFileURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = ["clip", "record", "--daemon-child"]
        if let logHandle {
            process.standardOutput = logHandle
            process.standardError = logHandle
        } else {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        do {
            try process.run()
            return true
        } catch {
            fputs("❌ 后台启动失败: \(error.localizedDescription)\n", stderr)
            return false
        }
    }

    /// 停止后台进程
    static func stop() -> Bool {
        guard let pid = readPid() else { return false }
        kill(pid, SIGTERM)
        // 等待进程退出
        for _ in 0..<20 {
            if kill(pid, 0) != 0 { break }
            usleep(50_000)
        }
        removePidFile()
        return true
    }

    // MARK: - LaunchAgent 自启

    /// 生成 plist 并加载（autostart on）
    static func installLaunchAgent(binaryPath: String) -> Bool {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>clip</string>
                <string>record</string>
                <string>--daemon-child</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>\(logFileURL.path)</string>
            <key>StandardErrorPath</key>
            <string>\(logFileURL.path)</string>
        </dict>
        </plist>
        """
        do {
            try FileManager.default.createDirectory(
                at: launchAgentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try plist.write(to: launchAgentURL, atomically: true, encoding: .utf8)
        } catch {
            fputs("❌ plist 写入失败: \(error.localizedDescription)\n", stderr)
            return false
        }
        return bootstrap(load: true)
    }

    /// 卸载并删除 plist（autostart off）
    static func removeLaunchAgent() -> Bool {
        _ = bootstrap(load: false)
        try? FileManager.default.removeItem(at: launchAgentURL)
        return true
    }

    static func autostartEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    private static func bootstrap(load: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        if load {
            process.arguments = ["bootstrap", "gui/\(getuid())", launchAgentURL.path]
        } else {
            process.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return true
        } catch {
            fputs("❌ launchctl 执行失败: \(error.localizedDescription)\n", stderr)
            return false
        }
    }
}
