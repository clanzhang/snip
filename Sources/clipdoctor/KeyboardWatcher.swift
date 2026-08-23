import Foundation
import CoreGraphics

// MARK: - 键盘监听器

/// 使用 CGEventTap 监听全局键盘事件
final class KeyboardWatcher {
    private let formatter: EventFormatter
    private let comboSet: Set<String>?   // nil = 全键盘模式
    private let unsafeChars: Bool
    private let logFile: FileHandle?

    private var runLoopSource: CFRunLoopSource?
    private var eventTap: CFMachPort?

    /// 默认监控的快捷键
    static let defaultCombos: [String] = [
        "cmd+c", "cmd+v", "cmd+x", "cmd+a", "cmd+z",
        "cmd+shift+z", "cmd+tab", "cmd+space", "cmd+q", "cmd+w",
        "opt+tab", "ctrl+space"
    ]

    // MARK: - 初始化

    /// - Parameters:
    ///   - combos: nil = 全键盘模式；非 nil = 只监控这些快捷键
    ///   - jsonMode: 是否 JSON Lines 输出
    ///   - unsafeChars: 是否输出字符内容（隐私警告）
    ///   - logPath: 日志文件路径（可选）
    init(combos: [String]?, jsonMode: Bool, unsafeChars: Bool, logPath: String?) {
        self.formatter = EventFormatter(jsonMode: jsonMode, showChars: unsafeChars)
        self.unsafeChars = unsafeChars

        if let combos = combos {
            // 标准化所有 combo 字符串
            let normalized = combos.map { KeyboardWatcher.normalizeCombo($0) }
            self.comboSet = Set(normalized)
        } else {
            self.comboSet = nil
        }

        // 打开日志文件
        if let path = logPath {
            let dir = (path as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil)
            }
            self.logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: path))
            self.logFile?.seekToEndOfFile()
        } else {
            self.logFile = nil
        }
    }

    // MARK: - 启动 / 停止

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
                                   | (1 << CGEventType.keyUp.rawValue)
                                   | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let watcher = Unmanaged<KeyboardWatcher>.fromOpaque(refcon!).takeUnretainedValue()
                watcher.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event) // 不吞事件，继续传递
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            fputs("无法创建 CGEventTap，请确认已授予输入监控权限。\n", stderr)
            exit(1)
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        logFile?.synchronizeFile()
        try? logFile?.close()
    }

    // MARK: - 事件处理

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let eventType: KeyEventType
        switch type {
        case .keyDown:      eventType = .keyDown
        case .keyUp:        eventType = .keyUp
        case .flagsChanged: eventType = .flagsChanged
        default:            return
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let repeatKey = (type == .keyDown) && event.getIntegerValueField(.keyboardEventAutorepeat) == 1
        let app = FrontAppDetector.current()
        let modifiers = Self.describeModifiers(flags)

        if let comboSet = comboSet {
            // 快捷键模式：只输出匹配的 combo
            guard let combo = Self.matchCombo(keyCode: keyCode, flags: flags, comboSet: comboSet) else {
                return
            }
            let line = formatter.formatCombo(eventType: eventType, combo: combo, keyCode: keyCode, modifiers: modifiers, app: app, repeat: repeatKey)
            output(line)
        } else {
            // 全键盘模式
            if unsafeChars, let char = Self.keyCodeToChar(keyCode: keyCode, flags: flags) {
                let line = formatter.formatAllKeysWithChar(eventType: eventType, keyCode: keyCode, modifiers: modifiers, app: app, repeat: repeatKey, char: char)
                output(line)
            } else {
                let line = formatter.formatAllKeys(eventType: eventType, keyCode: keyCode, modifiers: modifiers, app: app, repeat: repeatKey)
                output(line)
            }
        }
    }

    private func output(_ line: String) {
        print(line)
        fflush(stdout)

        if let handle = logFile, let data = (line + "\n").data(using: .utf8) {
            handle.write(data)
        }
    }

    // MARK: - 静态工具方法

    /// 描述修饰键
    static func describeModifiers(_ flags: CGEventFlags) -> String {
        var parts: [String] = []
        if flags.contains(.maskCommand) { parts.append("cmd") }
        if flags.contains(.maskShift)   { parts.append("shift") }
        if flags.contains(.maskAlternate) { parts.append("opt") }
        if flags.contains(.maskControl) { parts.append("ctrl") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }

    /// 标准化 combo 字符串："Command+C" → "cmd+c", "Ctrl+Space" → "ctrl+space"
    static func normalizeCombo(_ raw: String) -> String {
        let lower = raw.lowercased()
        var parts = lower.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        parts = parts.map { part in
            switch part {
            case "command", "cmd": return "cmd"
            case "shift":          return "shift"
            case "option", "opt", "alt": return "opt"
            case "control", "ctrl": return "ctrl"
            default: return part
            }
        }
        return parts.sorted().joined(separator: "+")
    }

    /// 将 keyCode 和 flags 转为 combo 字符串，检查是否在 comboSet 中
    static func matchCombo(keyCode: Int64, flags: CGEventFlags, comboSet: Set<String>) -> String? {
        let keyLabel = keyCodeToLabel(keyCode)
        guard keyLabel != "unknown" else { return nil }

        let modifiers = describeModifiers(flags)
        guard modifiers != "none" else { return nil }

        let combo = (modifiers.split(separator: "+").map(String.init) + [keyLabel])
            .sorted().joined(separator: "+")

        return comboSet.contains(combo) ? combo : nil
    }

    /// keyCode → 键标签（用于 combo 匹配）
    static func keyCodeToLabel(_ code: Int64) -> String {
        switch code {
        case 0:   return "a"
        case 1:   return "s"
        case 2:   return "d"
        case 3:   return "f"
        case 4:   return "h"
        case 5:   return "g"
        case 6:   return "z"
        case 7:   return "x"
        case 8:   return "c"
        case 9:   return "v"
        case 11:  return "b"
        case 12:  return "q"
        case 13:  return "w"
        case 14:  return "e"
        case 15:  return "r"
        case 16:  return "y"
        case 17:  return "t"
        case 31:  return "o"
        case 32:  return "u"
        case 34:  return "i"
        case 35:  return "p"
        case 37:  return "l"
        case 38:  return "j"
        case 40:  return "k"
        case 45:  return "n"
        case 46:  return "m"
        case 48:  return "tab"
        case 49:  return "space"
        case 51:  return "delete"
        case 53:  return "escape"
        case 36:  return "return"
        case 122: return "f1"
        case 120: return "f2"
        case 99:  return "f3"
        case 118: return "f4"
        case 96:  return "f5"
        case 97:  return "f6"
        case 98:  return "f7"
        case 100: return "f8"
        case 101: return "f9"
        case 109: return "f10"
        case 103: return "f11"
        case 111: return "f12"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default:  return "unknown"
        }
    }

    /// keyCode → 字符（仅 --unsafe-chars 模式使用）
    static func keyCodeToChar(keyCode: Int64, flags: CGEventFlags) -> String? {
        // 使用 CGEvent 的键盘事件来获取字符
        // 这里用简单的映射表，覆盖常见可打印字符
        let base = keyCodeToLabel(keyCode)
        if base.count == 1 {
            let c = Character(base)
            if flags.contains(.maskShift) {
                return String(c).uppercased()
            }
            return String(c)
        }
        return nil
    }
}