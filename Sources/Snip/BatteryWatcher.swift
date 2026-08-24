import Foundation

// MARK: - 电池数据模型

struct BatteryInfo {
    let currentCapacity: Int       // mAh
    let maxCapacity: Int           // mAh
    let designCapacity: Int        // mAh
    let cycleCount: Int
    let percentage: Int            // 0-100
    let isCharging: Bool
    let isFullyCharged: Bool
    let isPluggedIn: Bool
    let timeRemaining: Int?        // 分钟
    let temperature: Double?       // 摄氏度
    let healthPercent: Int         // 电池健康度 (max/design * 100)
    let powerSource: String        // "Battery" / "AC Power"

    var formattedPercentage: String {
        "\(percentage)%"
    }

    var statusText: String {
        if isFullyCharged { return "已充满" }
        if isCharging { return "充电中" }
        return "放电中"
    }
}

// MARK: - 电池监控器

final class BatteryWatcher {
    private var timer: Timer?
    private let interval: TimeInterval

    var onUpdate: ((BatteryInfo) -> Void)?

    init(interval: TimeInterval = 2.0) {
        self.interval = interval
    }

    /// 获取单次电池信息（通过 pmset 命令）
    static func fetch() -> BatteryInfo? {
        // pmset -g batt 输出示例:
        // Now drawing from 'Battery Power'
        //  -InternalBattery-0 (id=1234567) 85%; discharging; 3:15 remaining present: true

        let process = Process()
        process.launchPath = "/usr/bin/pmset"
        process.arguments = ["-g", "batt"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        // 解析百分比
        let percentage = parsePercentage(from: output)
        // 解析状态
        let isCharging = output.contains("charging") && !output.contains("discharging")
        let isFullyCharged = output.contains("charged") && !output.contains("discharging")
        let isPluggedIn = output.contains("AC Power")
        let powerSource = isPluggedIn ? "AC Power" : "Battery Power"

        // 解析剩余时间
        let timeRemaining = parseTimeRemaining(from: output)

        // 获取详细电池信息
        let (currentCapacity, maxCapacity, designCapacity, cycleCount, temperature) = fetchDetailedInfo()

        // 健康度
        let healthPercent = designCapacity > 0 ? Int(Double(maxCapacity) / Double(designCapacity) * 100) : 100

        return BatteryInfo(
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            designCapacity: designCapacity,
            cycleCount: cycleCount,
            percentage: percentage,
            isCharging: isCharging,
            isFullyCharged: isFullyCharged,
            isPluggedIn: isPluggedIn,
            timeRemaining: timeRemaining,
            temperature: temperature,
            healthPercent: healthPercent,
            powerSource: powerSource
        )
    }

    // MARK: - 解析

    private static func parsePercentage(from output: String) -> Int {
        // 匹配 "85%" 或 " 85%"
        if let range = output.range(of: #"\d+%"#, options: .regularExpression) {
            let pct = String(output[range]).dropLast()
            return Int(pct) ?? 0
        }
        return 0
    }

    private static func parseTimeRemaining(from output: String) -> Int? {
        // 匹配 "3:15 remaining" 或 "0:45 remaining" 或 "(no estimate)"
        if let range = output.range(of: #"\d+:\d+"#, options: .regularExpression) {
            let parts = String(output[range]).split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                return parts[0] * 60 + parts[1]
            }
        }
        return nil
    }

    private static func fetchDetailedInfo() -> (current: Int, max: Int, design: Int, cycles: Int, temp: Double?) {
        // ioreg -r -c AppleSmartBattery 输出所有电池属性
        let process = Process()
        process.launchPath = "/usr/sbin/ioreg"
        process.arguments = ["-r", "-c", "AppleSmartBattery", "-l"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return (0, 1, 1, 0, nil)
        }

        let current = parseInt(from: output, key: "CurrentCapacity")
        let max = parseInt(from: output, key: "MaxCapacity")
        let design = parseInt(from: output, key: "DesignCapacity")
        let cycles = parseInt(from: output, key: "CycleCount")

        // 温度：ioreg 中 "Temperature" = 2850 (单位 0.01°C)
        let rawTemp = parseInt(from: output, key: "Temperature")
        let temp: Double? = rawTemp > 0 ? Double(rawTemp) / 100.0 : nil

        return (current, max, design, cycles, temp)
    }

    private static func parseInt(from text: String, key: String) -> Int {
        // 匹配 "\"Key\" = 12345"
        if let range = text.range(of: #""\#(key)" = \d+"#, options: .regularExpression) {
            let line = String(text[range])
            if let numRange = line.range(of: #"\d+"#, options: .regularExpression) {
                return Int(line[numRange]) ?? 0
            }
        }
        return 0
    }

    // MARK: - 轮询

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, let info = BatteryWatcher.fetch() else { return }
            self.onUpdate?(info)
        }
        // 立即触发一次
        if let info = BatteryWatcher.fetch() {
            onUpdate?(info)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 格式化

extension BatteryInfo {
    var icon: String {
        if isFullyCharged { return "🔋" }
        if isCharging { return "⚡" }
        switch percentage {
        case 0..<10:  return "🪫"
        case 10..<25: return "🪫"
        case 25..<50: return "🪫"
        default:      return "🔋"
        }
    }

    var summary: String {
        var parts: [String] = ["\(icon) \(percentage)%  \(statusText)"]

        if let time = timeRemaining, time > 0 {
            let h = time / 60
            let m = time % 60
            if h > 0 {
                parts.append("剩余 \(h)h\(m)m")
            } else {
                parts.append("剩余 \(m)min")
            }
        }

        parts.append("健康度 \(healthPercent)%")
        parts.append("循环 \(cycleCount)次")

        if let temp = temperature {
            parts.append("\(String(format: "%.1f", temp))°C")
        }

        return parts.joined(separator: "  ")
    }
}