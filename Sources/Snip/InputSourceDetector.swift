import Carbon

/// 输入法检测
struct InputSourceDetector {
    static func current() -> String {
        if let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
            if let idPtr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) {
                return Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            }
        }
        return "unknown"
    }

    static func currentName() -> String {
        if let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
            if let namePtr = TISGetInputSourceProperty(src, kTISPropertyLocalizedName) {
                return Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
            }
        }
        return "unknown"
    }
}