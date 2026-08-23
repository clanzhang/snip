import Foundation

/// 事件格式化：文本 / JSON Lines
struct EventFormatter {
    private let iso: ISO8601DateFormatter
    private let time: DateFormatter

    init() {
        iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        iso.timeZone = TimeZone.current

        time = DateFormatter()
        time.dateFormat = "HH:mm:ss.SSS"
        time.locale = Locale(identifier: "en_US_POSIX")
    }

    // MARK: - 剪贴板

    func clipboardEvent(_ e: ClipboardEvent, json: Bool) -> String {
        if json { return clipboardJSON(e) }
        let ts = time.string(from: e.timestamp)
        return "\(ts) clipboard changed | changeCount=\(e.changeCount) | types=\(e.types.first ?? "unknown") | app=\(e.appName) | bundle=\(e.bundleId)"
    }

    private func clipboardJSON(_ e: ClipboardEvent) -> String {
        toJSON([
            "timestamp": iso.string(from: e.timestamp),
            "event": "clipboard_changed",
            "changeCount": e.changeCount,
            "types": e.types,
            "isText": e.isText,
            "isImage": e.isImage,
            "isFileURL": e.isFileURL,
            "app": e.appName,
            "bundleId": e.bundleId,
            "pid": e.pid
        ])
    }

    // MARK: - 键盘

    func keyboardEvent(_ e: KeyboardEvent, json: Bool) -> String {
        if json { return keyboardJSON(e) }
        let ts = time.string(from: e.timestamp)
        let combo = e.combo ?? "?"
        var line = "\(ts) \(e.type.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0)) | combo=\(combo) | keyCode=\(e.keyCode) | modifiers=\(e.modifiers) | app=\(e.appName) | bundle=\(e.bundleId) | repeat=\(e.repeat)"
        if let char = e.char { line += " | char=\(char)" }
        return line
    }

    private func keyboardJSON(_ e: KeyboardEvent) -> String {
        var dict: [String: Any] = [
            "timestamp": iso.string(from: e.timestamp),
            "event": e.type.rawValue,
            "keyCode": e.keyCode,
            "modifiers": e.modifiers,
            "repeat": e.repeat,
            "app": e.appName,
            "bundleId": e.bundleId,
            "pid": e.pid
        ]
        if let c = e.combo { dict["combo"] = c }
        if let ch = e.char { dict["char"] = ch }
        return toJSON(dict)
    }

    // MARK: - 复制失败

    func copyFailureEvent(_ e: CopyFailure, json: Bool) -> String {
        if json {
            return toJSON([
                "timestamp": iso.string(from: e.timestamp),
                "event": "copy_failure",
                "combo": e.combo,
                "app": e.app,
                "bundleId": e.bundleId,
                "pid": e.pid,
                "previousChangeCount": e.previousChangeCount,
                "currentChangeCount": e.currentChangeCount,
                "timeoutMilliseconds": e.timeoutMs
            ])
        }
        let ts = time.string(from: e.timestamp)
        return "\(ts) ❌ copy timeout | combo=\(e.combo) app=\(e.app) | changeCount unchanged"
    }

    // MARK: - 辅助

    private func toJSON(_ dict: [String: Any]) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: dict),
              let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }
}