import Foundation

// MARK: - 数据模型

/// 历史记录类型：文本记录完整内容；图片/文件只记元数据
enum HistoryType: String, Codable {
    case text, image, file
}

/// 一条剪贴板历史记录（元数据；文本内容在独立的 <id>.txt 文件中）
struct HistoryEntry: Codable, Equatable {
    let id: String
    var createdAt: Date
    var updatedAt: Date
    var appName: String
    var bundleId: String
    var type: HistoryType
    var pinned: Bool
    var preview: String
}

// MARK: - 存储

/// 剪贴板历史存储：目录下每个条目一个 <id>.txt（文本内容），元数据集中在 index.json
/// 排序规则：置顶优先，其次按更新时间倒序
final class HistoryStore {
    private(set) var entries: [HistoryEntry]
    let directory: URL
    let maxEntries: Int

    private let indexURL: URL
    private let lock = NSLock()

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("snip/history", isDirectory: true)
    }

    init(directory: URL? = nil, maxEntries: Int = 500) {
        self.directory = directory ?? HistoryStore.defaultDirectory()
        self.maxEntries = maxEntries
        self.indexURL = self.directory.appendingPathComponent("index.json")
        self.entries = HistoryStore.loadIndex(from: self.indexURL)
    }

    // MARK: - 索引读写

    private static func loadIndex(from url: URL) -> [HistoryEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let list = try decoder.decode([HistoryEntry].self, from: data)
            return Self.sorted(list)
        } catch {
            // 索引损坏：备份后以空索引启动，不丢失用户数据文件
            try? FileManager.default.copyItem(at: url, to: url.appendingPathExtension("bak"))
            return []
        }
    }

    private func saveIndex() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            fputs("⚠️ 索引写入失败: \(error.localizedDescription)\n", stderr)
        }
    }

    // MARK: - 增

    /// 新增一条文本记录；与最近一条内容相同则只更新时间（相邻去重）
    @discardableResult
    func add(text: String, appName: String, bundleId: String) -> HistoryEntry {
        lock.lock(); defer { lock.unlock() }
        if let recent = mostRecent(), recent.type == .text,
           let recentContent = contentUnsafe(id: recent.id),
           recentContent == text {
            var updated = recent
            updated.updatedAt = Date()
            updated.appName = appName
            updated.bundleId = bundleId
            replace(updated)
            sortEntries()
            saveIndex()
            return updated
        }
        let entry = HistoryEntry(
            id: Self.makeID(),
            createdAt: Date(),
            updatedAt: Date(),
            appName: appName,
            bundleId: bundleId,
            type: .text,
            pinned: false,
            preview: Self.preview(of: text)
        )
        writeContent(entry.id, text)
        entries.append(entry)
        sortEntries()
        trim()
        saveIndex()
        return entry
    }

    /// 图片/文件等非文本内容：只记元数据，不去重
    @discardableResult
    func addMetadata(type: HistoryType, appName: String, bundleId: String) -> HistoryEntry {
        lock.lock(); defer { lock.unlock() }
        let entry = HistoryEntry(
            id: Self.makeID(),
            createdAt: Date(),
            updatedAt: Date(),
            appName: appName,
            bundleId: bundleId,
            type: type,
            pinned: false,
            preview: type == .image ? "[图片]" : "[文件]"
        )
        entries.append(entry)
        sortEntries()
        trim()
        saveIndex()
        return entry
    }

    // MARK: - 查

    var count: Int { entries.count }

    func get(id: String) -> HistoryEntry? {
        entries.first { $0.id == id }
    }

    /// 读取文本内容（非文本条目返回 nil）
    func content(id: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return contentUnsafe(id: id)
    }

    func list(search: String? = nil, limit: Int? = nil, pinnedOnly: Bool = false) -> [HistoryEntry] {
        var result = entries
        if pinnedOnly {
            result = result.filter { $0.pinned }
        }
        if let q = search, !q.isEmpty {
            result = result.filter { $0.preview.localizedCaseInsensitiveContains(q) }
        }
        if let n = limit, n > 0 {
            result = Array(result.prefix(n))
        }
        return result
    }

    // MARK: - 改

    /// 修改文本内容，更新时间戳与预览
    @discardableResult
    func update(id: String, text: String) -> HistoryEntry? {
        lock.lock(); defer { lock.unlock() }
        guard var entry = get(id: id), entry.type == .text else { return nil }
        entry.updatedAt = Date()
        entry.preview = Self.preview(of: text)
        replace(entry)
        writeContent(id, text)
        sortEntries()
        saveIndex()
        return entry
    }

    @discardableResult
    func setPinned(id: String, pinned: Bool) -> HistoryEntry? {
        lock.lock(); defer { lock.unlock() }
        guard var entry = get(id: id) else { return nil }
        entry.pinned = pinned
        replace(entry)
        sortEntries()
        saveIndex()
        return entry
    }

    // MARK: - 删

    @discardableResult
    func delete(id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return false }
        entries.remove(at: idx)
        try? FileManager.default.removeItem(at: contentURL(id))
        saveIndex()
        return true
    }

    /// 清空全部历史，返回删除条数
    @discardableResult
    func clear() -> Int {
        lock.lock(); defer { lock.unlock() }
        let n = entries.count
        entries.removeAll()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        saveIndex()
        return n
    }

    // MARK: - 内部

    private func mostRecent() -> HistoryEntry? {
        entries.max { a, b in a.updatedAt < b.updatedAt }
    }

    private func replace(_ entry: HistoryEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        }
    }

    private func sortEntries() {
        entries.sort { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.updatedAt > b.updatedAt
        }
    }

    /// 超过上限时删除最旧的未置顶条目（置顶条目不受裁剪影响）
    private func trim() {
        guard entries.count > maxEntries else { return }
        let unpinnedByNewest = entries.filter { !$0.pinned }
            .sorted { $0.updatedAt > $1.updatedAt }
        let overflow = entries.count - maxEntries
        let toRemove = unpinnedByNewest.suffix(overflow)
        for e in toRemove {
            if let idx = entries.firstIndex(where: { $0.id == e.id }) {
                entries.remove(at: idx)
            }
            try? FileManager.default.removeItem(at: contentURL(e.id))
        }
    }

    private func contentURL(_ id: String) -> URL {
        directory.appendingPathComponent("\(id).txt")
    }

    private func contentUnsafe(id: String) -> String? {
        guard get(id: id)?.type == .text else { return nil }
        return try? String(contentsOf: contentURL(id), encoding: .utf8)
    }

    private func writeContent(_ id: String, _ text: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? text.write(to: contentURL(id), atomically: true, encoding: .utf8)
    }

    static func sorted(_ list: [HistoryEntry]) -> [HistoryEntry] {
        list.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.updatedAt > b.updatedAt
        }
    }

    static func makeID() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let ts = fmt.string(from: Date())
        let rand = String(format: "%06x", Int.random(in: 0...0xFFFFFF))
        return "\(ts)-\(rand)"
    }

    /// 列表预览：压成一行，最长 80 字符
    static func preview(of text: String, max: Int = 80) -> String {
        let oneLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        if oneLine.count <= max { return oneLine }
        return String(oneLine.prefix(max)) + "…"
    }
}
