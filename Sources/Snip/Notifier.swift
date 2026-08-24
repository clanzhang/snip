import AppKit
import Foundation

/// macOS 通知发送器
struct Notifier {
    private let center: NSUserNotificationCenter

    init() {
        center = NSUserNotificationCenter.default
    }

    func notify(title: String, subtitle: String, body: String) {
        let note = NSUserNotification()
        note.title = title
        note.subtitle = subtitle
        note.informativeText = body
        note.soundName = NSUserNotificationDefaultSoundName
        center.deliver(note)
    }

    /// 复制失败通知
    func copyFailure(app: String) {
        notify(
            title: "复制失败",
            subtitle: "Command+C 后剪贴板没变化",
            body: "应用: \(app)"
        )
    }
}