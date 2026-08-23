import AppKit
import Foundation

/// 复制失败检测器：检测 Command+C 后剪贴板是否变化
final class CopyFailureDetector {
    private let timeoutMs: Int
    private let pasteboard = NSPasteboard.general

    var onFailure: ((CopyFailure) -> Void)?
    var onSuccess: ((CopySuccess) -> Void)?

    init(timeoutMs: Int = 800) {
        self.timeoutMs = timeoutMs
    }

    /// 收到 cmd+c keyDown 时调用
    func onCopyPressed(app: AppInfo) {
        let before = pasteboard.changeCount
        let timestamp = Date()

        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) {
            let after = self.pasteboard.changeCount
            if before == after {
                let failure = CopyFailure(
                    timestamp: Date(),
                    combo: "cmd+c",
                    app: app.name,
                    bundleId: app.bundleId,
                    pid: app.pid,
                    previousChangeCount: before,
                    currentChangeCount: after,
                    timeoutMs: self.timeoutMs
                )
                self.onFailure?(failure)
            } else {
                let success = CopySuccess(
                    timestamp: timestamp,
                    combo: "cmd+c",
                    app: app.name,
                    bundleId: app.bundleId,
                    pid: app.pid,
                    previousChangeCount: before,
                    currentChangeCount: after,
                    timeoutMs: self.timeoutMs
                )
                self.onSuccess?(success)
            }
        }
    }
}

/// 复制成功事件
struct CopySuccess {
    let timestamp: Date
    let combo: String
    let app: String
    let bundleId: String
    let pid: Int32
    let previousChangeCount: Int
    let currentChangeCount: Int
    let timeoutMs: Int
}