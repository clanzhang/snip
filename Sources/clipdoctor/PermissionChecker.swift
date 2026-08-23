import Foundation
import CoreGraphics

/// 检查输入监控权限
struct PermissionChecker {

    /// 检查是否有输入监控权限（CGEvent 监听权限）
    /// macOS 10.15+ 使用 CGPreflightListenEventAccess
    static func hasInputMonitoringPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        } else {
            // 10.14 及以下：尝试创建 tap 来检测，失败即无权限
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
                callback: { _, _, _, _ in return nil },
                userInfo: nil
            ) else {
                return false
            }
            CFMachPortInvalidate(tap)
            return true
        }
    }

    /// 权限提示文案
    static let permissionGuide = """
        CmdCV 需要输入监控权限才能监听全局键盘事件。
        请前往：系统设置 > 隐私与安全性 > 输入监控
        为你运行此命令的终端应用授权，例如 Terminal、iTerm、Warp 或 VS Code。
        授权后重新运行命令。
        """

    /// 检查权限，无权限则打印提示并退出
    static func checkOrExit() {
        guard hasInputMonitoringPermission() else {
            print(permissionGuide)
            exit(1)
        }
    }
}