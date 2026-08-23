import AppKit
import Foundation

/// 全局键盘事件监听（CGEventTap）
final class KeyboardWatcher {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let comboSet: Set<HotKey>?
    private let allKeys: Bool
    private let unsafeChars: Bool

    var onEvent: ((KeyboardEvent) -> Void)?

    /// - Parameters:
    ///   - combos: nil = 全键盘模式；非 nil = 只匹配指定快捷键
    ///   - allKeys: 是否输出所有键盘事件
    ///   - unsafeChars: 是否输出按键字符
    init(combos: Set<HotKey>?, allKeys: Bool = false, unsafeChars: Bool = false) {
        self.comboSet = combos
        self.allKeys = allKeys
        self.unsafeChars = unsafeChars
    }

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
                                   | (1 << CGEventType.keyUp.rawValue)
                                   | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let w = Unmanaged<KeyboardWatcher>.fromOpaque(refcon).takeUnretainedValue()
                w.handle(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passRetained(self).toOpaque()
        ) else {
            fputs("无法创建键盘事件监听。\n\(PermissionChecker.guide())\n", stderr)
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.commonModes)
        self.runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, CFRunLoopMode.commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        tap = nil
        runLoopSource = nil
    }

    // MARK: - 事件处理

    private func handle(type: CGEventType, event: CGEvent) {
        let eventType: KeyEventType
        switch type {
        case .keyDown:      eventType = .keyDown
        case .keyUp:        eventType = .keyUp
        case .flagsChanged: eventType = .flagsChanged
        default:            return
        }

        // 快捷键模式：跳过 flagsChanged
        if comboSet != nil && eventType == .flagsChanged { return }

        let keyCode = Int64(event.getIntegerValueField(.keyboardEventKeycode))
        let mods = modifiersFrom(event.flags)
        let repeatKey = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let app = FrontAppDetector.current()

        // 快捷键模式
        if let combos = comboSet {
            let hot = HotKey(keyCode: keyCode, modifiers: mods)
            guard combos.contains(hot) else { return }

            let kb = KeyboardEvent(
                timestamp: Date(),
                type: eventType,
                keyCode: keyCode,
                modifiers: hot.modifierNames,
                combo: hot.label,
                repeat: repeatKey,
                appName: app.name,
                bundleId: app.bundleId,
                pid: app.pid,
                char: nil
            )
            onEvent?(kb)
            return
        }

        // 全键盘模式
        if allKeys {
            var char: String? = nil
            if unsafeChars {
                char = event.getUnicodeChar()
            }

            let comboLabel = comboLabelFrom(keyCode: keyCode, flags: event.flags)
            let kb = KeyboardEvent(
                timestamp: Date(),
                type: eventType,
                keyCode: keyCode,
                modifiers: hotKeyModifierNames(mods),
                combo: comboLabel,
                repeat: repeatKey,
                appName: app.name,
                bundleId: app.bundleId,
                pid: app.pid,
                char: char
            )
            onEvent?(kb)
        }
    }

    // MARK: - 辅助

    private func modifiersFrom(_ flags: CGEventFlags) -> Modifiers {
        var m: Modifiers = []
        if flags.contains(.maskCommand) { m.insert(.command) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskControl) { m.insert(.control) }
        if flags.contains(.maskShift)   { m.insert(.shift) }
        return m
    }

    private func comboLabelFrom(keyCode: Int64, flags: CGEventFlags) -> String? {
        let m = modifiersFrom(flags)
        if m.isEmpty { return nil }
        let label = Self.keyCodeToLabel(keyCode)
        return "\(hotKeyModifierNames(m))+\(label)"
    }

    private func hotKeyModifierNames(_ mods: Modifiers) -> String {
        var parts: [String] = []
        if mods.contains(.command) { parts.append("cmd") }
        if mods.contains(.option)  { parts.append("opt") }
        if mods.contains(.control) { parts.append("ctrl") }
        if mods.contains(.shift)   { parts.append("shift") }
        return parts.joined(separator: "+")
    }

    // MARK: - keyCode ↔ label

    static func keyCodeToLabel(_ keyCode: Int64) -> String {
        switch keyCode {
        case 0:  return "a";    case 1:  return "s";    case 2:  return "d"
        case 3:  return "f";    case 4:  return "h";    case 5:  return "g"
        case 6:  return "z";    case 7:  return "x";    case 8:  return "c"
        case 9:  return "v";    case 11: return "b";    case 12: return "q"
        case 13: return "w";    case 14: return "e";    case 15: return "r"
        case 16: return "y";    case 17: return "t";    case 18: return "1"
        case 19: return "2";    case 20: return "3";    case 21: return "4"
        case 22: return "6";    case 23: return "5";    case 24: return "="
        case 25: return "9";    case 26: return "7";    case 27: return "-"
        case 28: return "8";    case 29: return "0";    case 30: return "]"
        case 31: return "o";    case 32: return "u";    case 33: return "["
        case 34: return "i";    case 35: return "p";    case 36: return "return"
        case 37: return "l";    case 38: return "j";    case 39: return "'"
        case 40: return "k";    case 41: return ";";    case 42: return "\\"
        case 43: return ",";    case 44: return "/";    case 45: return "n"
        case 46: return "m";    case 47: return ".";    case 48: return "tab"
        case 49: return "space"; case 51: return "delete"; case 53: return "esc"
        case 55: return "cmd";  case 56: return "shift"; case 57: return "capslock"
        case 58: return "option"; case 59: return "control"; case 63: return "fn"
        case 123: return "left"; case 124: return "right"
        case 125: return "down"; case 126: return "up"
        default:  return "key\(keyCode)"
        }
    }

    static func keyLabelToCode(_ label: String) -> Int64? {
        for code in 0...127 {
            if keyCodeToLabel(Int64(code)) == label { return Int64(code) }
        }
        return nil
    }

    // MARK: - 快捷键解析

    static func parseComboString(_ str: String) -> Set<HotKey> {
        var result = Set<HotKey>()
        for part in str.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            if let hk = parseSingleCombo(part.lowercased()) {
                result.insert(hk)
            }
        }
        return result
    }

    private static func parseSingleCombo(_ str: String) -> HotKey? {
        let parts = str.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        var mods: Modifiers = []
        var keyName: String?

        for p in parts {
            switch p {
            case "cmd", "command": mods.insert(.command)
            case "opt", "option":  mods.insert(.option)
            case "ctrl", "control": mods.insert(.control)
            case "shift":          mods.insert(.shift)
            default: keyName = p
            }
        }

        guard let name = keyName, let code = keyLabelToCode(name) else { return nil }
        return HotKey(keyCode: code, modifiers: mods)
    }

    // MARK: - 默认快捷键

    static let defaultCombos: Set<HotKey> = {
        let pairs: [([Modifier], String)] = [
            ([.command], "c"), ([.command], "v"), ([.command], "x"),
            ([.command], "a"), ([.command], "z"),
            ([.command, .shift], "z"),
            ([.command], "tab"), ([.command], "space"),
            ([.command], "q"), ([.command], "w"),
            ([.control], "space"),
        ]
        var result = Set<HotKey>()
        for (mods, key) in pairs {
            if let code = keyLabelToCode(key) {
                result.insert(HotKey(keyCode: code, modifiers: Modifiers(mods)))
            }
        }
        return result
    }()
}

// MARK: - 类型

struct Modifier: OptionSet, Hashable {
    let rawValue: UInt8
    static let command = Modifier(rawValue: 1 << 0)
    static let option  = Modifier(rawValue: 1 << 1)
    static let control = Modifier(rawValue: 1 << 2)
    static let shift   = Modifier(rawValue: 1 << 3)
}

typealias Modifiers = Modifier

struct HotKey: Hashable {
    let keyCode: Int64
    let modifiers: Modifiers

    var label: String {
        let m = modifierNames
        let k = KeyboardWatcher.keyCodeToLabel(keyCode)
        return m.isEmpty ? k : "\(m)+\(k)"
    }

    var modifierNames: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("cmd") }
        if modifiers.contains(.option)  { parts.append("opt") }
        if modifiers.contains(.control) { parts.append("ctrl") }
        if modifiers.contains(.shift)   { parts.append("shift") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }
}

// MARK: - CGEvent 扩展

extension CGEvent {
    func getUnicodeChar() -> String? {
        let maxLen = 4
        var chars = [UniChar](repeating: 0, count: maxLen)
        var actualLen = 0
        keyboardGetUnicodeString(maxStringLength: maxLen, actualStringLength: &actualLen, unicodeString: &chars)
        guard actualLen > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: actualLen)
    }
}