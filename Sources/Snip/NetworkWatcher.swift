import Foundation

// MARK: - 网络数据模型

struct NetworkInfo {
    let interfaces: [NetworkInterface]
    let wifiSSID: String?
    let wifiRSSI: Int?          // dBm, 越接近 0 越好
    let wifiChannel: Int?
    let dnsServers: [String]
    let publicIP: String?
    let connectivity: Bool      // 是否能访问互联网
    let timestamp: Date

    var isWiFiConnected: Bool { wifiSSID != nil }
    var signalStrength: String {
        guard let rssi = wifiRSSI else { return "N/A" }
        switch rssi {
        case ..<(-80): return "弱"
        case ..<(-60): return "一般"
        case ..<(-40): return "强"
        default:      return "优秀"
        }
    }
}

struct NetworkInterface {
    let name: String            // en0, en1, lo0...
    let displayName: String     // Wi-Fi, Ethernet...
    let address: String?
    let netmask: String?
    let isActive: Bool
}

// MARK: - 网络监控器

final class NetworkWatcher {
    private var timer: Timer?
    private let interval: TimeInterval

    var onUpdate: ((NetworkInfo) -> Void)?

    init(interval: TimeInterval = 5.0) {
        self.interval = interval
    }

    // MARK: - 获取网络信息

    static func fetch() -> NetworkInfo {
        let interfaces = fetchInterfaces()
        let wifi = fetchWiFiInfo()
        let dns = fetchDNS()
        let publicIP = fetchPublicIP()
        let connectivity = checkConnectivity()

        return NetworkInfo(
            interfaces: interfaces,
            wifiSSID: wifi.ssid,
            wifiRSSI: wifi.rssi,
            wifiChannel: wifi.channel,
            dnsServers: dns,
            publicIP: publicIP,
            connectivity: connectivity,
            timestamp: Date()
        )
    }

    // MARK: - 网络接口 (ifconfig)

    private static func fetchInterfaces() -> [NetworkInterface] {
        let process = Process()
        process.launchPath = "/sbin/ifconfig"
        process.arguments = []
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var interfaces: [NetworkInterface] = []
        var currentName = ""
        var currentAddr: String?
        var currentMask: String?
        var currentActive = false

        for line in output.split(separator: "\n") {
            let l = String(line)

            // 接口名（行首无空格）
            if !l.hasPrefix("\t") && !l.hasPrefix(" ") {
                // 保存上一个
                if !currentName.isEmpty {
                    interfaces.append(NetworkInterface(
                        name: currentName,
                        displayName: displayName(for: currentName),
                        address: currentAddr,
                        netmask: currentMask,
                        isActive: currentActive
                    ))
                }
                currentName = String(l.split(separator: ":").first ?? "")
                currentAddr = nil
                currentMask = nil
                currentActive = l.contains("UP") && l.contains("RUNNING")
                continue
            }

            // inet 地址
            if l.contains("inet ") && !l.contains("inet6") {
                let parts = l.split(separator: " ").map(String.init)
                if let idx = parts.firstIndex(of: "inet"), idx + 1 < parts.count {
                    currentAddr = parts[idx + 1]
                }
                if let idx = parts.firstIndex(of: "netmask"), idx + 1 < parts.count {
                    currentMask = parts[idx + 1]
                    // 可能以 0x 开头
                    if currentMask?.hasPrefix("0x") == true {
                        currentMask = hexMaskToDecimal(String(currentMask!.dropFirst(2)))
                    }
                }
            }
        }

        // 最后一个
        if !currentName.isEmpty {
            interfaces.append(NetworkInterface(
                name: currentName,
                displayName: displayName(for: currentName),
                address: currentAddr,
                netmask: currentMask,
                isActive: currentActive
            ))
        }

        return interfaces.filter { !$0.name.hasPrefix("utun") && !$0.name.hasPrefix("llw") && !$0.name.hasPrefix("bridge") }
    }

    private static func hexMaskToDecimal(_ hex: String) -> String {
        guard let val = UInt32(hex, radix: 16) else { return hex }
        return "\(val >> 24).\((val >> 16) & 0xff).\((val >> 8) & 0xff).\(val & 0xff)"
    }

    private static func displayName(for interface: String) -> String {
        switch interface {
        case "en0": return "Wi-Fi"
        case let s where s.hasPrefix("en"): return "Ethernet"
        case "lo0": return "Loopback"
        case let s where s.hasPrefix("awdl"): return "AirDrop"
        case let s where s.hasPrefix("anpi"): return "Apple Note"
        default: return interface
        }
    }

    // MARK: - Wi-Fi 信息

    private static func fetchWiFiInfo() -> (ssid: String?, rssi: Int?, channel: Int?) {
        // 优先使用 airport 命令（提供更详细的信息）
        let airportPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        if FileManager.default.fileExists(atPath: airportPath) {
            let process = Process()
            process.launchPath = airportPath
            process.arguments = ["-I"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            process.launch()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let ssid = parseLine(output, key: "SSID")
                let rssi = parseInt(output, key: "agrCtlRSSI")
                let channel = parseInt(output, key: "channel")
                return (ssid, rssi, channel)
            }
        }

        // 回退：networksetup
        return fetchWiFiInfoViaNetworkSetup()
    }

    private static func fetchWiFiInfoViaNetworkSetup() -> (ssid: String?, rssi: Int?, channel: Int?) {
        // 获取 SSID
        let ssid = fetchSSIDViaNetworkSetup()

        // 获取 RSSI 和频道
        let detail = fetchWiFiDetail()

        return (ssid, detail.rssi, detail.channel)
    }

    private static func fetchSSIDViaNetworkSetup() -> String? {
        let process = Process()
        process.launchPath = "/usr/sbin/networksetup"
        process.arguments = ["-getairportnetwork", "en0"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        // 输出格式: "Current Wi-Fi Network: MyWiFi"
        if let range = output.range(of: "Current Wi-Fi Network: ") {
            return String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func fetchWiFiDetail() -> (rssi: Int?, channel: Int?) {
        // 使用 /System/Library/PrivateFrameworks/Apple80211.framework 的 airport 获取 RSSI
        // 如果不可用，用 system_profiler 获取
        let process = Process()
        process.launchPath = "/usr/sbin/system_profiler"
        process.arguments = ["SPAirPortDataType"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return (nil, nil) }

        let rssi = parseInt(output, key: "RSSI")
        let channel = parseInt(output, key: "Channel")

        return (rssi, channel)
    }

    // MARK: - DNS (scutil)

    private static func fetchDNS() -> [String] {
        let process = Process()
        process.launchPath = "/usr/sbin/scutil"
        process.arguments = ["--dns"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var servers: [String] = []
        for line in output.split(separator: "\n") {
            let l = String(line).trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("nameserver["), let range = l.range(of: "] : ") {
                let ip = String(l[range.upperBound...])
                if !servers.contains(ip) {
                    servers.append(ip)
                }
            }
        }
        return servers
    }

    // MARK: - 公网 IP

    private static func fetchPublicIP() -> String? {
        let process = Process()
        process.launchPath = "/usr/bin/curl"
        process.arguments = ["-s", "--connect-timeout", "3", "--max-time", "5", "https://ifconfig.me"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty,
              output.contains(".") else { return nil }
        return output
    }

    // MARK: - 连通性检测

    private static func checkConnectivity() -> Bool {
        let process = Process()
        process.launchPath = "/sbin/ping"
        process.arguments = ["-c", "1", "-t", "2", "8.8.8.8"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.launch()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    // MARK: - 解析工具

    private static func parseLine(_ text: String, key: String) -> String? {
        for line in text.split(separator: "\n") {
            let l = String(line).trimmingCharacters(in: .whitespaces)
            if l.hasPrefix(key + ":"), let range = l.range(of: ": ") {
                let val = String(l[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { return val }
            }
        }
        return nil
    }

    private static func parseInt(_ text: String, key: String) -> Int? {
        guard let str = parseLine(text, key: key) else { return nil }
        return Int(str)
    }

    // MARK: - 轮询

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let info = NetworkWatcher.fetch()
            self.onUpdate?(info)
        }
        // 立即触发
        let info = NetworkWatcher.fetch()
        onUpdate?(info)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 格式化

extension NetworkInfo {
    var summary: String {
        var lines: [String] = []

        // Wi-Fi
        if let ssid = wifiSSID {
            let signal = wifiRSSI.map { "\($0) dBm (\(signalStrength))" } ?? "N/A"
            lines.append("📶 Wi-Fi: \(ssid)  信号: \(signal)")
            if let ch = wifiChannel {
                lines.append("   频道: \(ch)")
            }
        } else {
            lines.append("📶 Wi-Fi: 未连接")
        }

        // 活跃接口
        let active = interfaces.filter { $0.isActive && $0.address != nil }
        if !active.isEmpty {
            lines.append("🌐 网络接口:")
            for iface in active {
                let addr = iface.address ?? "N/A"
                lines.append("   \(iface.name) (\(iface.displayName)): \(addr)")
            }
        }

        // DNS
        if !dnsServers.isEmpty {
            lines.append("📋 DNS: \(dnsServers.joined(separator: ", "))")
        }

        // 公网 IP
        if let ip = publicIP {
            lines.append("🌍 公网 IP: \(ip)")
        }

        // 连通性
        lines.append("🔗 互联网: \(connectivity ? "✅ 可达" : "❌ 不可达")")

        if !connectivity {
            lines.append("   ⚠️ 网络不通可能导致 Universal Clipboard (通用剪贴板) 失效")
        }

        return lines.joined(separator: "\n")
    }
}