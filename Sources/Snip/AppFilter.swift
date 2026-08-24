import Foundation

/// 应用过滤器：支持白名单/黑名单，决定是否对某个应用的事件输出
struct AppFilter {
    /// 只输出这些应用（空 = 全部）
    let only: [String]
    /// 忽略这些应用
    let ignore: [String]

    /// 是否应该输出该应用的事件
    func shouldOutput(appName: String, bundleId: String) -> Bool {
        if !only.isEmpty {
            return only.contains(where: { match(bundleId, against: $0) || match(appName, against: $0) })
        }
        if !ignore.isEmpty {
            if ignore.contains(where: { match(bundleId, against: $0) || match(appName, against: $0) }) {
                return false
            }
        }
        return true
    }

    /// 解析逗号分隔的过滤列表
    static func parse(_ raw: String?) -> [String] {
        guard let raw = raw else { return [] }
        return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// 忽略大小写的包含匹配
    private func match(_ value: String, against pattern: String) -> Bool {
        return value.lowercased().contains(pattern.lowercased())
    }
}