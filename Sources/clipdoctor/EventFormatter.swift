import Foundation
import CoreGraphics

// MARK: - 键盘事件数据结构

/// 键盘事件类型
enum KeyEventType: String, Codable {
    case keyDown
    case keyUp
    case flagsChanged
}

// MARK: - 事件格式化

/// 键盘事件格式化器：支持默认文本和 JSON Lines 两种输出
struct EventFormatter {
    let jsonMode: Bool
    let showChars: Bool  // --unsafe-chars

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone.current
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: 格式化入口

    /// 格式化一条快捷键事件
    func formatCombo(eventType: KeyEventType, combo: String, keyCode: Int64, modifiers: String, app: FrontAppDetector, repeat: Bool) -> String {
        if jsonMode {
            return jsonLine(eventType: eventType, combo: combo, keyCode: keyCode, modifiers: modifiers, app: app, repeat: `repeat`, char: nil)
        }
        return "\(timeFormatter.string(from: Date())) \(eventType.rawValue) combo=\(combo) app=\(app.name) bundle=\(app.bundleID) repeat=\(`repeat`)"
    }

    /// 格式化一条全键盘事件（无字符）
    func formatAllKeys(eventType: KeyEventType, keyCode: Int64, modifiers: String, app: FrontAppDetector, repeat: Bool) -> String {
        if jsonMode {
            return jsonLine(eventType: eventType, combo: nil, keyCode: keyCode, modifiers: modifiers, app: app, repeat: `repeat`, char: nil)
        }
        return "\(timeFormatter.string(from: Date())) \(eventType.rawValue) keyCode=\(keyCode) modifiers=\(modifiers) app=\(app.name) repeat=\(`repeat`)"
    }

    /// 格式化一条全键盘事件（含字符，--unsafe-chars）
    func formatAllKeysWithChar(eventType: KeyEventType, keyCode: Int64, modifiers: String, app: FrontAppDetector, repeat: Bool, char: String) -> String {
        if jsonMode {
            return jsonLine(eventType: eventType, combo: nil, keyCode: keyCode, modifiers: modifiers, app: app, repeat: `repeat`, char: char)
        }
        return "\(timeFormatter.string(from: Date())) \(eventType.rawValue) keyCode=\(keyCode) modifiers=\(modifiers) char=\(char) app=\(app.name) repeat=\(`repeat`)"
    }

    // MARK: JSON 序列化

    private func jsonLine(eventType: KeyEventType, combo: String?, keyCode: Int64, modifiers: String, app: FrontAppDetector, repeat: Bool, char: String?) -> String {
        var dict: [String: Any] = [
            "timestamp": dateFormatter.string(from: Date()),
            "type": eventType.rawValue,
            "keyCode": keyCode,
            "modifiers": modifiers.split(separator: "+").map(String.init),
            "app": app.name,
            "bundleId": app.bundleID,
            "pid": app.pid,
            "repeat": `repeat`
        ]
        if let combo = combo { dict["combo"] = combo }
        if let char = char { dict["char"] = char }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}