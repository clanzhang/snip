import AppKit
import Foundation

// 确保 AppKit 应用模式启动（NSWorkspace 需要）
let app = NSApplication.shared

// 阻止 Dock 图标显示（纯后台命令行工具）
app.setActivationPolicy(.accessory)

let monitor = ClipboardMonitor(pollInterval: 0.5)

// 捕获 SIGINT / SIGTERM，优雅退出
signal(SIGINT) { _ in
    print("\n收到 SIGINT，正在退出...")
    monitor.stop()
    exit(0)
}
signal(SIGTERM) { _ in
    print("\n收到 SIGTERM，正在退出...")
    monitor.stop()
    exit(0)
}

print("ClipDoctor 剪贴板诊断工具启动中...")
print("按 Ctrl+C 停止")
print("日志文件: ~/.cmdcv/monitor.log\n")

monitor.start()

// 运行主事件循环
app.run()