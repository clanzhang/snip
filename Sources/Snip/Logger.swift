import Foundation

/// 文件日志器：~/Library/Logs/snip/snip.log，超过 10MB 自动轮转为 snip.log.old
struct Logger {
    private let logDir: URL
    private let logFile: URL
    private let oldFile: URL
    private let dateFormatter: DateFormatter
    private var fileHandle: FileHandle?
    private let maxSize: Int64 = 10_485_760 // 10MB

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        logDir = home.appendingPathComponent("Library/Logs/snip")
        logFile = logDir.appendingPathComponent("snip.log")
        oldFile = logDir.appendingPathComponent("snip.log.old")

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        openHandle()
    }

    private mutating func openHandle() {
        fileHandle = try? FileHandle(forWritingTo: logFile)
        fileHandle?.seekToEndOfFile()
    }

    mutating func log(_ message: String) {
        let ts = dateFormatter.string(from: Date())
        let line = "[\(ts)] \(message)\n"

        // 秒起输出到 stdout
        print(line, terminator: "")

        guard let data = line.data(using: .utf8), let handle = fileHandle else { return }

        // 轮转
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
           let size = attrs[.size] as? Int64, size > maxSize {
            rotate()
        }

        handle.write(data)
        handle.synchronizeFile()
    }

    private mutating func rotate() {
        fileHandle?.synchronizeFile()
        try? fileHandle?.close()
        fileHandle = nil

        try? FileManager.default.removeItem(at: oldFile)
        try? FileManager.default.copyItem(at: logFile, to: oldFile)
        try? "".write(to: logFile, atomically: true, encoding: .utf8)

        openHandle()
    }

    func flush() {
        fileHandle?.synchronizeFile()
    }
}