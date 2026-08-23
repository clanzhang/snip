import AppKit
import Foundation

/// 剪贴板监控器：轮询 changeCount 检测剪贴板变化
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private let logger = Logger()
    private let pollInterval: TimeInterval

    private var lastChangeCount: Int
    private var timer: Timer?

    /// - Parameter pollInterval: 轮询间隔（秒），建议 0.2 ~ 0.5
    init(pollInterval: TimeInterval = 0.5) {
        self.pollInterval = pollInterval
        self.lastChangeCount = pasteboard.changeCount
    }

    // MARK: - 启动 / 停止

    func start() {
        logger.log("=== ClipDoctor 启动 ===")
        logger.log("轮询间隔: \(pollInterval)s | 日志目录: ~/.cmdcv/")

        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkPasteboard()
        }

        // 让 Timer 在 RunLoop 常见模式下都能触发
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        logger.log("=== ClipDoctor 停止 ===")
    }

    // MARK: - 剪贴板检查

    private func checkPasteboard() {
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else {
            return // 无变化，跳过
        }

        lastChangeCount = currentCount
        let app = AppInfo.frontmost()
        let types = pasteboard.types ?? []
        let typeDesc = describeTypes(types)
        let preview = contentPreview(types: types)

        logger.log("剪贴板变化 | changeCount: \(currentCount) | 应用: \(app.name)(\(app.bundleID)) | 类型: \(typeDesc)\(preview)")
    }

    // MARK: - 内容描述

    /// 将剪贴板类型列表转为可读描述
    private func describeTypes(_ types: [NSPasteboard.PasteboardType]) -> String {
        let typeNames = types.map { type -> String in
            switch type {
            case .string:        return "text"
            case .rtf:           return "rtf"
            case .html:          return "html"
            case .pdf:           return "pdf"
            case .png:           return "png"
            case .tiff:          return "tiff"
            case .fileURL:       return "fileURL"
            case .URL:           return "url"
            case .color:         return "color"
            case .tabularText:   return "tabularText"
            case .findPanelSearchOptions: return "findPanel"
            default:
                // 去掉 "public." 等前缀，让输出更短
                let raw = type.rawValue
                if raw.hasPrefix("public.") {
                    return String(raw.dropFirst(7))
                } else if raw.hasPrefix("com.apple.") {
                    return String(raw.dropFirst(10))
                }
                return raw
            }
        }
        return typeNames.isEmpty ? "无" : typeNames.joined(separator: ", ")
    }

    /// 对文本类型内容生成预览（最多 100 字符，避免泄露过多隐私）
    private func contentPreview(types: [NSPasteboard.PasteboardType]) -> String {
        // 优先取纯文本
        if types.contains(.string),
           let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let maxLen = 100
            if trimmed.count > maxLen {
                let preview = String(trimmed.prefix(maxLen))
                return " | 文本预览: \"\(preview)...\""
            } else {
                return " | 文本预览: \"\(trimmed)\""
            }
        }

        // 文件 URL
        if types.contains(.fileURL),
           let url = pasteboard.string(forType: .fileURL) {
            return " | 文件: \(url)"
        }

        return ""
    }
}