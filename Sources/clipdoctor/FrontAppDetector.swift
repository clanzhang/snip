import AppKit
import Foundation

/// 前台应用信息，包含 PID
struct FrontAppDetector {
    let name: String
    let bundleID: String
    let pid: Int32

    static func current() -> FrontAppDetector {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return FrontAppDetector(name: "unknown", bundleID: "unknown", pid: -1)
        }
        return FrontAppDetector(
            name: app.localizedName ?? "unknown",
            bundleID: app.bundleIdentifier ?? "unknown",
            pid: app.processIdentifier
        )
    }
}