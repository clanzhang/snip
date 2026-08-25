import Foundation

// MARK: - 命令选项

struct WatchOptions {
    var interval: TimeInterval = 0.3
    var contentPreview: Int = 0
    var json: Bool = false
    var verbose: Bool = false
    var log: Bool = false
    var ignore: String?
    var only: String?
    var theme: String = "light"
}

struct KeysOptions {
    var customKeys: String?
    var allKeys: Bool = false
    var unsafeChars: Bool = false
    var json: Bool = false
    var verbose: Bool = false
    var log: Bool = false
    var ignore: String?
    var only: String?
    var theme: String = "light"
}

struct AllOptions {
    var interval: TimeInterval = 0.3
    var contentPreview: Int = 0
    var json: Bool = false
    var verbose: Bool = false
    var log: Bool = false
    var notify: Bool = false
    var ignore: String?
    var only: String?
    var theme: String = "light"
}

struct TestOptions {
    var clipboard: Bool = false
    var keys: Bool = false
    var latency: Bool = false
}

struct ReportOptions {
    var output: String = "~/Desktop/snip-report.txt"
}

struct ServerOptions {
    var port: Int = 9876
}

struct BatteryOptions {
    var watch: Bool = false
    var interval: TimeInterval = 2.0
    var json: Bool = false
    var warnThreshold: Int? = nil   // 电量低于此百分比时发送提醒，默认 15
}

struct NetworkOptions {
    var watch: Bool = false
    var interval: TimeInterval = 5.0
    var json: Bool = false
}

// MARK: - 命令枚举

enum SnipCommand {
    case help
    case version
    case watch(WatchOptions)
    case keys(KeysOptions)
    case all(AllOptions)
    case doctor
    case test(TestOptions)
    case stats
    case report(ReportOptions)
    case server(ServerOptions)
    case battery(BatteryOptions)
    case network(NetworkOptions)
    case unknown(String)

    init(args: [String]) {
        guard args.count >= 2 else {
            self = .help
            return
        }

        let sub = args[1]
        let rest = Array(args.dropFirst(2))

        switch sub {
        case "--help", "-h":
            self = .help
        case "--version", "-v":
            self = .version
        case "watch":
            self = .watch(Self.parseWatch(rest))
        case "keys":
            self = .keys(Self.parseKeys(rest))
        case "all":
            self = .all(Self.parseAll(rest))
        case "doctor":
            self = .doctor
        case "test":
            self = .test(Self.parseTest(rest))
        case "stats":
            self = .stats
        case "report":
            self = .report(Self.parseReport(rest))
        case "server":
            self = .server(Self.parseServer(rest))
        case "battery":
            self = .battery(Self.parseBattery(rest))
        case "network":
            self = .network(Self.parseNetwork(rest))
        default:
            self = .unknown(sub)
        }
    }

    // MARK: - 参数解析

    private static func parseWatch(_ args: [String]) -> WatchOptions {
        var opts = WatchOptions()
        for (i, a) in args.enumerated() {
            switch a {
            case "--json": opts.json = true
            case "--verbose": opts.verbose = true
            case "--log": opts.log = true
            case "--interval":
                if i + 1 < args.count { opts.interval = Double(args[i + 1]) ?? 0.3 }
            case let a where a.hasPrefix("--interval="):
                opts.interval = Double(String(a.dropFirst("--interval=".count))) ?? 0.3
            case "--content-preview":
                if i + 1 < args.count { opts.contentPreview = Int(args[i + 1]) ?? 0 }
            case let a where a.hasPrefix("--content-preview="):
                opts.contentPreview = Int(String(a.dropFirst("--content-preview=".count))) ?? 0
            case "--ignore":
                if i + 1 < args.count { opts.ignore = args[i + 1] }
            case let a where a.hasPrefix("--ignore="):
                opts.ignore = String(a.dropFirst("--ignore=".count))
            case "--only":
                if i + 1 < args.count { opts.only = args[i + 1] }
            case let a where a.hasPrefix("--only="):
                opts.only = String(a.dropFirst("--only=".count))
            case "--theme":
                if i + 1 < args.count { opts.theme = args[i + 1] }
            case let a where a.hasPrefix("--theme="):
                opts.theme = String(a.dropFirst("--theme=".count))
            default: break
            }
        }
        return opts
    }

    private static func parseKeys(_ args: [String]) -> KeysOptions {
        var opts = KeysOptions()
        for (i, a) in args.enumerated() {
            switch a {
            case "--json": opts.json = true
            case "--verbose": opts.verbose = true
            case "--log": opts.log = true
            case "--all-keys": opts.allKeys = true
            case "--unsafe-chars": opts.unsafeChars = true
            case "--keys":
                if i + 1 < args.count { opts.customKeys = args[i + 1] }
            case let a where a.hasPrefix("--keys="):
                opts.customKeys = String(a.dropFirst("--keys=".count))
            case "--ignore":
                if i + 1 < args.count { opts.ignore = args[i + 1] }
            case let a where a.hasPrefix("--ignore="):
                opts.ignore = String(a.dropFirst("--ignore=".count))
            case "--only":
                if i + 1 < args.count { opts.only = args[i + 1] }
            case let a where a.hasPrefix("--only="):
                opts.only = String(a.dropFirst("--only=".count))
            case "--theme":
                if i + 1 < args.count { opts.theme = args[i + 1] }
            case let a where a.hasPrefix("--theme="):
                opts.theme = String(a.dropFirst("--theme=".count))
            default: break
            }
        }
        return opts
    }

    private static func parseAll(_ args: [String]) -> AllOptions {
        var opts = AllOptions()
        for (i, a) in args.enumerated() {
            switch a {
            case "--json": opts.json = true
            case "--verbose": opts.verbose = true
            case "--log": opts.log = true
            case "--notify": opts.notify = true
            case "--interval":
                if i + 1 < args.count { opts.interval = Double(args[i + 1]) ?? 0.3 }
            case let a where a.hasPrefix("--interval="):
                opts.interval = Double(String(a.dropFirst("--interval=".count))) ?? 0.3
            case "--content-preview":
                if i + 1 < args.count { opts.contentPreview = Int(args[i + 1]) ?? 0 }
            case let a where a.hasPrefix("--content-preview="):
                opts.contentPreview = Int(String(a.dropFirst("--content-preview=".count))) ?? 0
            case "--ignore":
                if i + 1 < args.count { opts.ignore = args[i + 1] }
            case let a where a.hasPrefix("--ignore="):
                opts.ignore = String(a.dropFirst("--ignore=".count))
            case "--only":
                if i + 1 < args.count { opts.only = args[i + 1] }
            case let a where a.hasPrefix("--only="):
                opts.only = String(a.dropFirst("--only=".count))
            case "--theme":
                if i + 1 < args.count { opts.theme = args[i + 1] }
            case let a where a.hasPrefix("--theme="):
                opts.theme = String(a.dropFirst("--theme=".count))
            default: break
            }
        }
        return opts
    }

    private static func parseTest(_ args: [String]) -> TestOptions {
        var opts = TestOptions()
        if args.contains("--clipboard") { opts.clipboard = true }
        if args.contains("--keys") { opts.keys = true }
        if args.contains("--latency") { opts.latency = true }
        return opts
    }

    private static func parseReport(_ args: [String]) -> ReportOptions {
        var opts = ReportOptions()
        for (i, a) in args.enumerated() {
            if a == "--output", i + 1 < args.count {
                opts.output = args[i + 1]
            } else if a.hasPrefix("--output=") {
                opts.output = String(a.dropFirst("--output=".count))
            }
        }
        return opts
    }

    private static func parseServer(_ args: [String]) -> ServerOptions {
        var opts = ServerOptions()
        for (i, a) in args.enumerated() {
            if a == "--port", i + 1 < args.count {
                opts.port = Int(args[i + 1]) ?? 9876
            } else if a.hasPrefix("--port=") {
                opts.port = Int(String(a.dropFirst("--port=".count))) ?? 9876
            }
        }
        return opts
    }

    private static func parseBattery(_ args: [String]) -> BatteryOptions {
        var opts = BatteryOptions()
        for (i, a) in args.enumerated() {
            switch a {
            case "--watch": opts.watch = true
            case "--json": opts.json = true
            case "--interval":
                if i + 1 < args.count { opts.interval = Double(args[i + 1]) ?? 2.0 }
            case let a where a.hasPrefix("--interval="):
                opts.interval = Double(String(a.dropFirst("--interval=".count))) ?? 2.0
            case "--warn":
                opts.warnThreshold = 15  // 默认 15%
                if i + 1 < args.count, let n = Int(args[i + 1]), n > 0, n <= 100 {
                    opts.warnThreshold = n
                }
            case let a where a.hasPrefix("--warn="):
                let val = Int(String(a.dropFirst("--warn=".count))) ?? 15
                opts.warnThreshold = max(1, min(100, val))
            default: break
            }
        }
        return opts
    }

    private static func parseNetwork(_ args: [String]) -> NetworkOptions {
        var opts = NetworkOptions()
        for (i, a) in args.enumerated() {
            switch a {
            case "--watch": opts.watch = true
            case "--json": opts.json = true
            case "--interval":
                if i + 1 < args.count { opts.interval = Double(args[i + 1]) ?? 5.0 }
            case let a where a.hasPrefix("--interval="):
                opts.interval = Double(String(a.dropFirst("--interval=".count))) ?? 5.0
            default: break
            }
        }
        return opts
    }
}