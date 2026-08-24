import Foundation

/// 输出模式
enum OutputMode {
    case plain      // 默认：人类友好，简洁
    case verbose    // 完整技术字段
    case json       // JSON Lines
}

/// 颜色主题
enum ColorTheme {
    case light   // 默认终端色
    case dark    // 高亮色
    case none    // 纯文本，无 ANSI
}

/// 事件格式化：默认 / verbose / JSON 三层输出
struct EventFormatter {
    let mode: OutputMode
    let theme: ColorTheme

    private let timeShort: DateFormatter
    private let timeFull: DateFormatter
    private let iso: ISO8601DateFormatter

    init(mode: OutputMode = .plain, theme: ColorTheme = .light) {
        self.mode = mode
        self.theme = theme

        timeShort = DateFormatter()
        timeShort.dateFormat = "HH:mm:ss"
        timeShort.locale = Locale(identifier: "en_US_POSIX")

        timeFull = DateFormatter()
        timeFull.dateFormat = "HH:mm:ss.SSS"
        timeFull.locale = Locale(identifier: "en_US_POSIX")

        iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        iso.timeZone = TimeZone.current
    }

    // MARK: - 剪贴板

    func clipboardEvent(_ e: ClipboardEvent) -> String {
        switch mode {
        case .json:   return clipboardJSON(e)
        case .verbose: return clipboardVerbose(e)
        case .plain:   return clipboardPlain(e)
        }
    }

    private func clipboardPlain(_ e: ClipboardEvent) -> String {
        let ts = timeShort.string(from: e.timestamp)
        let app = shortAppName(e.appName, e.bundleId)
        let type = pasteboardTypeLabel(e)
        return "\(ts)  📋 剪贴板更新  \(app)  \(type)"
    }

    private func clipboardVerbose(_ e: ClipboardEvent) -> String {
        let ts = timeFull.string(from: e.timestamp)
        let types = e.types.isEmpty ? "unknown" : e.types.joined(separator: ", ")
        return "\(ts)  clipboard changed  changeCount=\(e.changeCount)  types=\(types)  app=\(e.appName)  bundle=\(e.bundleId)"
    }

    private func clipboardJSON(_ e: ClipboardEvent) -> String {
        toJSON([
            "time": timeFull.string(from: e.timestamp),
            "type": "clipboard_changed",
            "change_count": e.changeCount,
            "types": e.types,
            "app": e.appName,
            "bundle_id": e.bundleId,
            "pid": e.pid
        ])
    }

    // MARK: - 键盘

    func keyboardEvent(_ e: KeyboardEvent) -> String {
        switch mode {
        case .json:   return keyboardJSON(e)
        case .verbose: return keyboardVerbose(e)
        case .plain:   return keyboardPlain(e)
        }
    }

    private func keyboardPlain(_ e: KeyboardEvent) -> String {
        let ts = timeShort.string(from: e.timestamp)
        let app = shortAppName(e.appName, e.bundleId)
        let combo = humanReadableCombo(e.combo)
        return "\(ts)  ⌨️  \(combo)  \(app)"
    }

    private func keyboardVerbose(_ e: KeyboardEvent) -> String {
        let ts = timeFull.string(from: e.timestamp)
        let combo = e.combo ?? "?"
        var line = "\(ts)  \(e.type.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0))  combo=\(combo)  keyCode=\(e.keyCode)  modifiers=\(e.modifiers)  app=\(e.appName)  bundle=\(e.bundleId)  repeat=\(e.repeat)"
        if let char = e.char { line += "  char=\(char)" }
        return line
    }

    private func keyboardJSON(_ e: KeyboardEvent) -> String {
        var dict: [String: Any] = [
            "time": timeFull.string(from: e.timestamp),
            "type": e.type.rawValue,
            "key_code": e.keyCode,
            "modifiers": e.modifiers.split(separator: "+").map(String.init),
            "repeat": e.repeat,
            "app": e.appName,
            "bundle_id": e.bundleId,
            "pid": e.pid
        ]
        if let c = e.combo { dict["combo"] = c }
        if let ch = e.char { dict["char"] = ch }
        return toJSON(dict)
    }

    // MARK: - 复制失败

    func copyFailureEvent(_ e: CopyFailure) -> String {
        switch mode {
        case .json:   return copyFailureJSON(e)
        case .verbose: return copyFailureVerbose(e)
        case .plain:   return copyFailurePlain(e)
        }
    }

    private func copyFailurePlain(_ e: CopyFailure) -> String {
        let ts = timeShort.string(from: e.timestamp)
        let app = shortAppName(e.app, e.bundleId)
        return colorize("\(ts)  ❌ Command+C 后剪贴板没变化  \(app)", .red)
    }

    private func copyFailureVerbose(_ e: CopyFailure) -> String {
        let ts = timeFull.string(from: e.timestamp)
        return "\(ts)  ❌ copy timeout  combo=\(e.combo)  app=\(e.app)  changeCount unchanged"
    }

    private func copyFailureJSON(_ e: CopyFailure) -> String {
        return toJSON([
            "time": timeFull.string(from: e.timestamp),
            "type": "copy_failure",
            "combo": e.combo,
            "app": e.app,
            "bundle_id": e.bundleId,
            "pid": e.pid,
            "previous_change_count": e.previousChangeCount,
            "current_change_count": e.currentChangeCount,
            "timeout_ms": e.timeoutMs
        ])
    }

    // MARK: - 复制成功

    func copySuccessEvent(_ e: CopySuccess) -> String {
        switch mode {
        case .json:   return copySuccessJSON(e)
        case .verbose: return copySuccessVerbose(e)
        case .plain:   return copySuccessPlain(e)
        }
    }

    private func copySuccessPlain(_ e: CopySuccess) -> String {
        let ts = timeShort.string(from: e.timestamp)
        let app = shortAppName(e.app, e.bundleId)
        return colorize("\(ts)  ✅ 复制成功  \(app)", .green)
    }

    private func copySuccessVerbose(_ e: CopySuccess) -> String {
        let ts = timeFull.string(from: e.timestamp)
        return "\(ts)  ✅ copy success  combo=\(e.combo)  app=\(e.app)  changeCount \(e.previousChangeCount)→\(e.currentChangeCount)"
    }

    private func copySuccessJSON(_ e: CopySuccess) -> String {
        return toJSON([
            "time": timeFull.string(from: e.timestamp),
            "type": "copy_success",
            "combo": e.combo,
            "app": e.app,
            "bundle_id": e.bundleId,
            "pid": e.pid,
            "previous_change_count": e.previousChangeCount,
            "current_change_count": e.currentChangeCount,
            "timeout_ms": e.timeoutMs
        ])
    }

    // MARK: - 辅助

    /// 把 cmd+c → Command+C
    private func humanReadableCombo(_ raw: String?) -> String {
        guard let raw = raw else { return "?" }
        let parts = raw.split(separator: "+").map { part -> String in
            switch part.lowercased() {
            case "cmd":   return "Command"
            case "opt":   return "Option"
            case "ctrl":  return "Control"
            case "shift": return "Shift"
            default:      return part.uppercased()
            }
        }
        return parts.joined(separator: "+")
    }

    /// 从 bundleId 提取短名称，如 com.google.Chrome → Chrome
    private func shortAppName(_ name: String, _ bundleId: String) -> String {
        if name != "unknown" && !name.isEmpty { return name }
        let parts = bundleId.split(separator: ".")
        guard let last = parts.last else { return "unknown" }
        return String(last)
    }

    /// 剪贴板类型映射为中文标签
    private func pasteboardTypeLabel(_ e: ClipboardEvent) -> String {
        if e.isImage { return "图片" }
        if e.isFileURL { return "文件" }
        if e.isText { return "文本" }
        if e.types.isEmpty { return "未知" }
        return "其他"
    }

    // MARK: - JSON

    private func toJSON(_ dict: [String: Any]) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: dict),
              let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }

    // MARK: - ANSI 颜色

    private enum ANSI: String {
        case red    = "\u{001B}[31m"
        case green  = "\u{001B}[32m"
        case reset  = "\u{001B}[0m"
    }

    private func colorize(_ text: String, _ color: ANSI) -> String {
        guard theme != .none, isatty(STDOUT_FILENO) != 0 else { return text }
        return "\(color.rawValue)\(text)\(ANSI.reset.rawValue)"
    }
}