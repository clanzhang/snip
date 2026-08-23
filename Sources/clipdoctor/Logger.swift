import Foundation

/// 简易文件日志器，写入 ~/.cmdcv/monitor.log
struct Logger {
    private let logDir: URL
    private let logFile: URL
    private let dateFormatter: DateFormatter
    private let fileHandle: FileHandle?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        logDir = home.appendingPathComponent(".cmdcv")
        logFile = logDir.appendingPathComponent("monitor.log")

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        // 确保日志目录存在
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        // 创建日志文件（如果不存在）
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }

        // 打开文件句柄用于追加写入
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            fileHandle = handle
        } else {
            fileHandle = nil
        }
    }

    /// 写入一条日志（同时输出到 stdout）
    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        // 输出到终端
        print(line, terminator: "")

        // 写入文件
        if let data = line.data(using: .utf8), let handle = fileHandle {
            handle.write(data)
            handle.synchronizeFile()
        }
    }
}