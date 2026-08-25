import Foundation

// MARK: - CPU 数据模型

struct CPULoad {
    let user: Double
    let system: Double
    let idle: Double
    let nice: Double

    var used: Double { user + system + nice }
}

struct CPUInfo {
    let modelName: String
    let physicalCores: Int
    let logicalCores: Int
    let cpuUsage: CPULoad
    let processCount: Int
    let loadAverage1: Double
    let loadAverage5: Double
    let loadAverage15: Double
    let topProcesses: [(cpu: Double, name: String)]
}

// MARK: - CPU 监控器

final class CPUWatcher {
    private var timer: Timer?
    private let interval: TimeInterval
    private var lastTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    var onUpdate: ((CPUInfo) -> Void)?

    init(interval: TimeInterval = 3.0) {
        self.interval = interval
    }

    /// 获取单次 CPU 信息
    static func fetch() -> CPUInfo? {
        guard let model = fetchModel(),
              let cores = fetchCores(),
              let load = fetchLoadAverage(),
              let usage = fetchCPULoad() else { return nil }

        let (physical, logical) = cores
        let procCount = fetchProcessCount()
        let topProcs = fetchTopProcesses()

        return CPUInfo(
            modelName: model,
            physicalCores: physical,
            logicalCores: logical,
            cpuUsage: usage,
            processCount: procCount,
            loadAverage1: load.0,
            loadAverage5: load.1,
            loadAverage15: load.2,
            topProcesses: topProcs
        )
    }

    // MARK: - 静态数据采集

    private static func fetchModel() -> String? {
        let process = Process()
        process.launchPath = "/usr/sbin/sysctl"
        process.arguments = ["-n", "machdep.cpu.brand_string"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data.trimmingTrailingNewline(), encoding: .utf8)
    }

    private static func fetchCores() -> (physical: Int, logical: Int)? {
        let physical = sysctlInt("hw.physicalcpu") ?? 0
        let logical = sysctlInt("hw.logicalcpu") ?? 0
        guard physical > 0, logical > 0 else { return nil }
        return (physical, logical)
    }

    private static func fetchLoadAverage() -> (Double, Double, Double)? {
        var load: (Double, Double, Double) = (0, 0, 0)
        let result = getloadavg(&load.0, 3)
        guard result == 3 else { return nil }
        return load
    }

    /// 使用 host_statistics 获取 CPU ticks（累计值）
    private static func fetchCPULoad() -> CPULoad? {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let kr = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, ptr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let total = Double(cpuLoad.cpu_ticks.0 + cpuLoad.cpu_ticks.1 + cpuLoad.cpu_ticks.2 + cpuLoad.cpu_ticks.3)
        guard total > 0 else { return nil }

        return CPULoad(
            user: Double(cpuLoad.cpu_ticks.0) / total * 100,
            system: Double(cpuLoad.cpu_ticks.1) / total * 100,
            idle: Double(cpuLoad.cpu_ticks.2) / total * 100,
            nice: Double(cpuLoad.cpu_ticks.3) / total * 100
        )
    }

    /// 获取 top N CPU 进程（ps 按 CPU 降序）
    private static func fetchTopProcesses() -> [(cpu: Double, name: String)] {
        let process = Process()
        process.launchPath = "/bin/ps"
        process.arguments = ["-A", "-o", "%cpu,comm", "-r"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let lines = output.split(separator: "\n").dropFirst()  // 跳过标题行
        var results: [(cpu: Double, name: String)] = []
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // ps 输出格式: " 12.3 /Applications/xxx.app/..."
            // 按空格分割，第一个字段是 CPU，剩余是路径
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2, let cpu = Double(parts[0]) {
                let name = String(parts[1])
                results.append((cpu, name))
            }
        }
        return results
    }

    /// 统计进程数
    private static func fetchProcessCount() -> Int {
        let process = Process()
        process.launchPath = "/bin/ps"
        process.arguments = ["-A", "-o", "pid"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return 0 }
        return output.split(separator: "\n").count - 1  // 去掉标题行
    }

    // MARK: - 轮询

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, let info = CPUWatcher.fetch() else { return }
            self.onUpdate?(info)
        }
        if let info = CPUWatcher.fetch() {
            onUpdate?(info)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 辅助

private func sysctlInt(_ name: String) -> Int? {
    var value: Int = 0
    var size = MemoryLayout<Int>.size
    let result = sysctlbyname(name, &value, &size, nil, 0)
    guard result == 0 else { return nil }
    return value
}

extension Data {
    fileprivate func trimmingTrailingNewline() -> Data {
        guard let str = String(data: self, encoding: .utf8) else { return self }
        return str.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) ?? self
    }
}

// MARK: - 格式化

extension CPUInfo {
    var summary: String {
        var parts: [String] = []

        // CPU 型号
        let coreInfo: String
        if physicalCores == logicalCores {
            coreInfo = "\(physicalCores)核"
        } else {
            let eCores = logicalCores - physicalCores
            coreInfo = "\(physicalCores)核(\(physicalCores - eCores)性能+\(eCores)能效)"
        }
        parts.append("🧠 \(modelName)  \(coreInfo)")

        // 负载 & 进程数
        parts.append("📊 负载: \(String(format: "%.2f", loadAverage1)) \(String(format: "%.2f", loadAverage5)) \(String(format: "%.2f", loadAverage15))  进程: \(processCount)")

        // CPU 使用率
        parts.append("🔥 CPU: 用户 \(String(format: "%.1f", cpuUsage.user))%  系统 \(String(format: "%.1f", cpuUsage.system))%  空闲 \(String(format: "%.1f", cpuUsage.idle))%")

        // Top 进程
        if !topProcesses.isEmpty {
            let procs = topProcesses.prefix(3).map { "\(String(format: "%.1f", $0.cpu))% \($0.name)" }.joined(separator: "  ")
            parts.append("⚡ 进程: \(procs)")
        }

        return parts.joined(separator: "\n")
    }
}