import AppKit

/// 获取当前前台应用信息
struct AppInfo {
    /// 获取当前前台应用的名称和 Bundle ID
    static func frontmost() -> (name: String, bundleID: String) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return ("未知", "未知")
        }
        let name = app.localizedName ?? "未知"
        let bundleID = app.bundleIdentifier ?? "未知"
        return (name, bundleID)
    }
}