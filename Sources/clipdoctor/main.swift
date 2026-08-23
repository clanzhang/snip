import AppKit
import Foundation

// MARK: - 全局信号处理

/// 全局停止回调，由各个模式在启动前设置
private var signalStopHandler: (() -> Void)?

/// C 兼容的信号处理函数
private func signalHandler(_ sig: Int32) {
    if sig == SIGINT { print("\n收到 SIGINT，正在退出...") }
    if sig == SIGTERM { print("\n收到 SIGTERM，正在退出...") }
    signalStopHandler?()
    exit(0)
}

private func setupSignalHandlers() {
    signal(SIGINT, signalHandler)
    signal(SIGTERM, signalHandler)
}

// MARK: - 帮助信息

func printHelp() {
    print("""
    ClipDoctor - macOS 剪贴板 & 键盘诊断工具

    用法:
      clipdoctor                          默认模式：剪贴板监控
      clipdoctor keyboard watch [选项]     键盘事件监控

    剪贴板模式:
      无额外参数，启动后持续监控 NSPasteboard.general.changeCount
      日志写入 ~/.cmdcv/monitor.log

    键盘模式 (keyboard watch):
      --keys <list>     自定义快捷键，逗号分隔（默认: cmd+c,cmd+v,cmd+x,...）
      --all-keys        监控所有键盘事件（仅输出元数据，不输出字符）
      --unsafe-chars    输出按键字符内容（⚠️ 隐私警告）
      --json            JSON Lines 输出格式
      --log <path>      日志文件路径

    示例:
      clipdoctor                              # 剪贴板监控
      clipdoctor keyboard watch               # 默认快捷键监控
      clipdoctor keyboard watch --all-keys    # 全键盘事件
      clipdoctor keyboard watch --keys "cmd+c,cmd+v,ctrl+space"
      clipdoctor keyboard watch --all-keys --json --log ~/kb.log
      clipdoctor -h                           # 帮助

    权限:
      键盘监控需要「输入监控」权限。
      系统设置 > 隐私与安全性 > 输入监控
    """)
}

// MARK: - 键盘模式参数解析

struct KeyboardOptions {
    var combos: [String]?       // nil = 全键盘模式
    var allKeys: Bool = false
    var unsafeChars: Bool = false
    var jsonMode: Bool = false
    var logPath: String?
}

func parseKeyboardArgs(_ args: [String]) -> KeyboardOptions? {
    var opts = KeyboardOptions()
    var i = 0
    var hasKeysArg = false

    while i < args.count {
        switch args[i] {
        case "--all-keys":
            opts.allKeys = true
        case "--unsafe-chars":
            opts.unsafeChars = true
        case "--json":
            opts.jsonMode = true
        case "--keys":
            i += 1
            guard i < args.count else {
                fputs("错误: --keys 需要参数\n", stderr)
                return nil
            }
            hasKeysArg = true
            opts.combos = args[i].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        case "--log":
            i += 1
            guard i < args.count else {
                fputs("错误: --log 需要参数\n", stderr)
                return nil
            }
            opts.logPath = args[i]
        default:
            fputs("未知参数: \(args[i])\n", stderr)
            return nil
        }
        i += 1
    }

    if !hasKeysArg && !opts.allKeys {
        opts.combos = KeyboardWatcher.defaultCombos
    } else if opts.allKeys && hasKeysArg {
        fputs("错误: --keys 和 --all-keys 不能同时使用\n", stderr)
        return nil
    } else if opts.allKeys {
        opts.combos = nil
    }

    if opts.unsafeChars && !opts.allKeys {
        fputs("错误: --unsafe-chars 需要配合 --all-keys 使用\n", stderr)
        return nil
    }

    return opts
}

// MARK: - 键盘模式入口

func runKeyboardMode(args: [String]) {
    guard let opts = parseKeyboardArgs(args) else {
        exit(1)
    }

    if opts.unsafeChars {
        print("""
        ⚠️  警告：该模式会记录按键对应的字符内容，可能泄露密码、聊天记录和敏感信息。
        仅建议在本地调试时使用。

        """)
    }

    PermissionChecker.checkOrExit()

    let watcher = KeyboardWatcher(
        combos: opts.combos,
        jsonMode: opts.jsonMode,
        unsafeChars: opts.unsafeChars,
        logPath: opts.logPath
    )

    signalStopHandler = { watcher.stop() }
    setupSignalHandlers()

    if opts.combos != nil {
        print("键盘监控已启动（快捷键模式），按 Ctrl+C 停止")
    } else {
        print("键盘监控已启动（全键盘模式），按 Ctrl+C 停止")
    }

    watcher.start()
    CFRunLoopRun()
}

// MARK: - 剪贴板模式入口

func runClipboardMode() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let monitor = ClipboardMonitor(pollInterval: 0.5)

    signalStopHandler = { monitor.stop() }
    setupSignalHandlers()

    print("ClipDoctor 剪贴板诊断工具启动中...")
    print("按 Ctrl+C 停止")
    print("日志文件: ~/.cmdcv/monitor.log\n")

    monitor.start()
    app.run()
}

// MARK: - 主入口

let args = CommandLine.arguments

switch args.count {
case 1:
    runClipboardMode()

case 2:
    switch args[1] {
    case "-h", "--help":
        printHelp()
    default:
        printHelp()
        exit(1)
    }

default:
    if args[1] == "keyboard" && args.count >= 3 && args[2] == "watch" {
        runKeyboardMode(args: Array(args.dropFirst(3)))
    } else {
        printHelp()
        exit(1)
    }
}