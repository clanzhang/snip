import AppKit
import Darwin
import Foundation

/// 轻量 HTTP 诊断服务器：snip server [--port 9876]
struct Server {
    let port: Int

    init(port: Int = 9876) {
        self.port = port
    }

    func run() {
        let server = SimpleHTTPServer(port: port)
        print("snip 诊断服务器已启动: http://localhost:\(port)")
        print("请求 /status 查看状态")
        print("Ctrl+C 退出")

        signal(SIGINT) { _ in
            print("\n已停止。")
            exit(0)
        }

        server.start()
        RunLoop.main.run()
    }
}

// MARK: - 简易 HTTP 服务器

private final class SimpleHTTPServer: NSObject {
    private let port: Int
    private var listener: FileHandle?

    init(port: Int) {
        self.port = port
    }

    func start() {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            fputs("创建 socket 失败\n", stderr)
            exit(1)
        }

        var reuse = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        guard Darwin.bind(sock, UnsafeMutableRawPointer(&addr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size)) >= 0 else {
            fputs("绑定端口 \(port) 失败，端口可能已被占用\n", stderr)
            exit(1)
        }

        guard listen(sock, 5) >= 0 else {
            fputs("监听失败\n", stderr)
            exit(1)
        }

        listener = FileHandle(fileDescriptor: sock, closeOnDealloc: true)
        NotificationCenter.default.addObserver(forName: .NSFileHandleConnectionAccepted, object: listener, queue: nil) { [weak self] n in
            guard let self = self else { return }
            let client = n.userInfo?[NSFileHandleNotificationFileHandleItem] as? FileHandle
            self.handleClient(client) { client?.closeFile() }
            self.listener?.acceptConnectionInBackgroundAndNotify()
        }
        listener?.acceptConnectionInBackgroundAndNotify()
    }

    private func handleClient(_ fh: FileHandle?, done: @escaping () -> Void) {
        DispatchQueue.global().async {
            guard let fh = fh else { done(); return }
            let data = fh.readDataToEndOfFile()
            let request = String(data: data, encoding: .utf8) ?? ""
            let response = self.buildResponse(for: request)
            fh.write(response.data(using: .utf8) ?? Data())
            done()
        }
    }

    private func buildResponse(for request: String) -> String {
        let path = extractPath(from: request)
        let body: String
        let code: Int

        switch path {
        case "/status":
            body = statusJSON()
            code = 200
        default:
            body = statusJSON()
            code = 200
        }

        let statusText = code == 200 ? "OK" : "Not Found"
        return """
        HTTP/1.1 \(code) \(statusText)\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        \r
        \(body)
        """
    }

    private func extractPath(from request: String) -> String {
        let lines = request.split(separator: "\r\n")
        guard let first = lines.first else { return "/" }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return "/" }
        return String(parts[1])
    }

    private func statusJSON() -> String {
        var dict: [String: Any] = [
            "hostname": ProcessInfo.processInfo.hostName,
            "macos": "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)",
            "user": NSUserName(),
            "input_monitoring": PermissionChecker.hasInputMonitoring(),
            "accessibility": AXIsProcessTrusted(),
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        let tools = detectRunningTools()
        let toolNames = tools.map { "\($0.name) (\($0.bundleId))" }
        dict["detected_tools"] = toolNames
        return toJSON(dict)
    }

    private func detectRunningTools() -> [(name: String, bundleId: String)] {
        let known = [
            "com.raycast.macos", "com.alfredapp.alfred", "com.runningwithcrayons.Alfred",
            "com.hegenberg.BetterTouchTool", "com.keyboardmaestro.Keyboard-Maestro",
            "org.pqrs.Karabiner-Elements", "com.wiheads.paste", "com.maccy.maccy",
            "com.pilotmoon.copyclip", "com.cleanshot.CleanShot", "com.surteesstudios.Bartender",
        ]
        var result: [(name: String, bundleId: String)] = []
        for app in NSWorkspace.shared.runningApplications {
            if let bid = app.bundleIdentifier, known.contains(bid) {
                result.append((app.localizedName ?? bid, bid))
            }
        }
        return result
    }

    private func toJSON(_ dict: [String: Any]) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }
}