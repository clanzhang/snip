import Foundation

// MARK: - 命令选项

struct WatchOptions {
    var interval: TimeInterval = 0.3
    var contentPreview: Int = 0
    var json: Bool = false
    var log: Bool = false
}

struct KeysOptions {
    var customKeys: String?
    var allKeys: Bool = false
    var unsafeChars: Bool = false
    var json: Bool = false
    var log: Bool = false
}

struct AllOptions {
    var interval: TimeInterval = 0.3
    var contentPreview: Int = 0
    var json: Bool = false
    var log: Bool = false
}

struct TestOptions {
    var clipboard: Bool = false
    var keys: Bool = false
}

struct ReportOptions {
    var output: String = "~/Desktop/snip-report.txt"
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
            case "--log": opts.log = true
            case "--interval":
                if i + 1 < args.count { opts.interval = Double(args[i + 1]) ?? 0.3 }
            case let a where a.hasPrefix("--interval="):
                opts.interval = Double(String(a.dropFirst("--interval=".count))) ?? 0.3
            case "--content-preview":
                if i + 1 < args.count { opts.contentPreview = Int(args[i + 1]) ?? 0 }
            case let a where a.hasPrefix("--content-preview="):
                opts.contentPreview = Int(String(a.dropFirst("--content-preview=".count))) ?? 0
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
            case "--log": opts.log = true
            case "--all-keys": opts.allKeys = true
            case "--unsafe-chars": opts.unsafeChars = true
            case "--keys":
                if i + 1 < args.count { opts.customKeys = args[i + 1] }
            case let a where a.hasPrefix("--keys="):
                opts.customKeys = String(a.dropFirst("--keys=".count))
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
            case "--log": opts.log = true
            case "--interval":
                if i + 1 < args.count { opts.interval = Double(args[i + 1]) ?? 0.3 }
            case let a where a.hasPrefix("--interval="):
                opts.interval = Double(String(a.dropFirst("--interval=".count))) ?? 0.3
            case "--content-preview":
                if i + 1 < args.count { opts.contentPreview = Int(args[i + 1]) ?? 0 }
            case let a where a.hasPrefix("--content-preview="):
                opts.contentPreview = Int(String(a.dropFirst("--content-preview=".count))) ?? 0
            default: break
            }
        }
        return opts
    }

    private static func parseTest(_ args: [String]) -> TestOptions {
        var opts = TestOptions()
        if args.contains("--clipboard") { opts.clipboard = true }
        if args.contains("--keys") { opts.keys = true }
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
}