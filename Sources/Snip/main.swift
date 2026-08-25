import AppKit
import Foundation

// MARK: - 入口

let cli = CLI()
let command = SnipCommand(args: CommandLine.arguments)

switch command {
case .help:
    cli.printHelp()
case .version:
    cli.printVersion()
case .watch(let opts):
    cli.runWatch(opts: opts)
case .keys(let opts):
    cli.runKeys(opts: opts)
case .all(let opts):
    cli.runAll(opts: opts)
case .doctor:
    cli.runDoctor()
case .test(let opts):
    cli.runTest(opts: opts)
case .stats:
    cli.runStats()
case .report(let opts):
    cli.runReport(opts: opts)
case .server(let opts):
    cli.runServer(opts: opts)
case .battery(let opts):
    cli.runBattery(opts: opts)
case .network(let opts):
    cli.runNetwork(opts: opts)
case .unknown(let cmd):
    fputs("未知命令: \(cmd)\n\n", stderr)
    cli.printHelp()
    exit(1)
}