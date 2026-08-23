import AppKit
import Foundation

/// 输入监控权限检测
struct PermissionChecker {
    /// 通过尝试创建 CGEventTap 来判断是否有输入监控权限
    static func hasInputMonitoring() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, _, _ in return nil },
            userInfo: nil
        ) else {
            return false
        }
        CFMachPortInvalidate(tap)
        return true
    }

    static func guide() -> String {
        return """
        Snip 需要输入监控权限才能监听全局键盘事件。

        请前往：
        系统设置 > 隐私与安全性 > 输入监控

        为你运行此命令的终端应用授权，例如：
        - Terminal
        - iTerm
        - Warp
        - VS Code

        授权后重新运行 snip。
        """
    }
}