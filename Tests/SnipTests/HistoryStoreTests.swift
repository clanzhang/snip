import XCTest
@testable import Snip

final class HistoryStoreTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snip-test-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeStore(maxEntries: Int = 500) -> HistoryStore {
        HistoryStore(directory: dir, maxEntries: maxEntries)
    }

    // MARK: - 增

    func testAddWritesContentAndIndex() {
        let store = makeStore()
        let entry = store.add(text: "hello world", appName: "Safari", bundleId: "com.apple.Safari")

        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(store.get(id: entry.id)?.preview, "hello world")
        XCTAssertEqual(store.content(id: entry.id), "hello world")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(entry.id).txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("index.json").path))
    }

    func testAddPreviewTruncatesMultiline() {
        let store = makeStore()
        let long = String(repeating: "a", count: 100)
        let entry = store.add(text: "line1\nline2\(long)", appName: "X", bundleId: "x")

        let preview = store.get(id: entry.id)!.preview
        XCTAssertFalse(preview.contains("\n"))
        XCTAssertTrue(preview.count <= 81)  // 80 + …
        XCTAssertTrue(preview.hasSuffix("…"))
    }

    func testAdjacentDedupUpdatesTimestamp() {
        let store = makeStore()
        let first = store.add(text: "same", appName: "A", bundleId: "a")
        Thread.sleep(forTimeInterval: 0.01)
        let second = store.add(text: "same", appName: "B", bundleId: "b")

        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(store.get(id: first.id)?.appName, "B")  // 来源应用已更新
        XCTAssertGreaterThan(store.get(id: first.id)!.updatedAt, first.updatedAt)
    }

    func testSameTextNotAdjacentKeepsBoth() {
        let store = makeStore()
        store.add(text: "a", appName: "A", bundleId: "a")
        store.add(text: "b", appName: "B", bundleId: "b")
        store.add(text: "a", appName: "C", bundleId: "c")

        XCTAssertEqual(store.count, 3)
    }

    func testMaxCapTrimsOldestUnpinned() {
        let store = makeStore(maxEntries: 3)
        let e1 = store.add(text: "1", appName: "A", bundleId: "a")
        let e2 = store.add(text: "2", appName: "A", bundleId: "a")
        let e3 = store.add(text: "3", appName: "A", bundleId: "a")
        let e4 = store.add(text: "4", appName: "A", bundleId: "a")

        XCTAssertEqual(store.count, 3)
        XCTAssertNil(store.get(id: e1.id))
        XCTAssertNotNil(store.get(id: e2.id))
        XCTAssertNotNil(store.get(id: e3.id))
        XCTAssertNotNil(store.get(id: e4.id))
        // 被裁剪条目的 txt 文件已删除
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(e1.id).txt").path))
    }

    func testPinnedSurvivesTrim() {
        let store = makeStore(maxEntries: 3)
        let p1 = store.add(text: "keep", appName: "A", bundleId: "a")
        _ = store.setPinned(id: p1.id, pinned: true)
        store.add(text: "2", appName: "A", bundleId: "a")
        store.add(text: "3", appName: "A", bundleId: "a")
        store.add(text: "4", appName: "A", bundleId: "a")

        XCTAssertEqual(store.count, 3)
        XCTAssertNotNil(store.get(id: p1.id))
    }

    func testAddMetadataForImage() {
        let store = makeStore()
        let entry = store.addMetadata(type: .image, appName: "Preview", bundleId: "com.apple.Preview")

        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(entry.type, .image)
        XCTAssertEqual(store.get(id: entry.id)?.preview, "[图片]")
        XCTAssertNil(store.content(id: entry.id))
    }

    // MARK: - 查

    func testListSortsPinnedFirstThenTimeDesc() {
        let store = makeStore()
        store.add(text: "first", appName: "A", bundleId: "a")
        let second = store.add(text: "second", appName: "B", bundleId: "b")
        store.add(text: "third", appName: "C", bundleId: "c")
        _ = store.setPinned(id: second.id, pinned: true)

        let list = store.list()
        XCTAssertEqual(list.first?.id, second.id)   // 置顶在最前
        XCTAssertEqual(list.map(\.preview), ["second", "third", "first"])
    }

    func testSearchFiltersByPreview() {
        let store = makeStore()
        store.add(text: "hello world", appName: "A", bundleId: "a")
        store.add(text: "goodbye moon", appName: "B", bundleId: "b")

        XCTAssertEqual(store.list(search: "hello").count, 1)
        XCTAssertEqual(store.list(search: "MOON").count, 1)   // 大小写不敏感
        XCTAssertEqual(store.list(search: "xyz").count, 0)
    }

    func testLimitAndPinnedOnly() {
        let store = makeStore()
        store.add(text: "1", appName: "A", bundleId: "a")
        store.add(text: "2", appName: "B", bundleId: "b")
        store.add(text: "3", appName: "C", bundleId: "c")
        let e2 = store.get(id: store.list().first(where: { $0.preview == "2" })!.id)!
        _ = store.setPinned(id: e2.id, pinned: true)

        XCTAssertEqual(store.list(limit: 2).count, 2)
        XCTAssertEqual(store.list(pinnedOnly: true).count, 1)
    }

    // MARK: - 改

    func testUpdateChangesContentAndTimestamp() {
        let store = makeStore()
        let entry = store.add(text: "old", appName: "A", bundleId: "a")
        Thread.sleep(forTimeInterval: 0.01)

        guard let updated = store.update(id: entry.id, text: "new content") else {
            return XCTFail("update 返回 nil")
        }
        XCTAssertEqual(store.content(id: entry.id), "new content")
        XCTAssertEqual(updated.preview, "new content")
        XCTAssertGreaterThan(updated.updatedAt, entry.updatedAt)
    }

    func testUpdateMissingEntryReturnsNil() {
        let store = makeStore()
        XCTAssertNil(store.update(id: "nope", text: "x"))
    }

    func testPinUnpinRoundTrip() {
        let store = makeStore()
        let entry = store.add(text: "x", appName: "A", bundleId: "a")

        _ = store.setPinned(id: entry.id, pinned: true)
        XCTAssertTrue(store.get(id: entry.id)!.pinned)

        _ = store.setPinned(id: entry.id, pinned: false)
        XCTAssertFalse(store.get(id: entry.id)!.pinned)
    }

    // MARK: - 删

    func testDeleteRemovesEntryAndFile() {
        let store = makeStore()
        let entry = store.add(text: "bye", appName: "A", bundleId: "a")

        XCTAssertTrue(store.delete(id: entry.id))
        XCTAssertEqual(store.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(entry.id).txt").path))

        XCTAssertFalse(store.delete(id: entry.id))  // 已删除
    }

    func testClearRemovesEverything() {
        let store = makeStore()
        store.add(text: "1", appName: "A", bundleId: "a")
        store.add(text: "2", appName: "A", bundleId: "a")

        XCTAssertEqual(store.clear(), 2)
        XCTAssertEqual(store.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }

    // MARK: - 持久化

    func testPersistenceAcrossInstances() {
        let first = makeStore()
        let entry = first.add(text: "persist me", appName: "A", bundleId: "a")
        _ = first.setPinned(id: entry.id, pinned: true)

        let second = makeStore()
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second.get(id: entry.id)?.preview, "persist me")
        XCTAssertTrue(second.get(id: entry.id)!.pinned)
        XCTAssertEqual(second.content(id: entry.id), "persist me")
    }

    func testCorruptIndexRecoversWithBackup() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? Data("not json at all".utf8).write(to: dir.appendingPathComponent("index.json"))

        let store = makeStore()
        XCTAssertEqual(store.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("index.json.bak").path))
    }

    func testMissingDirectoryStartsEmpty() {
        let store = makeStore()
        XCTAssertEqual(store.count, 0)
        XCTAssertNil(store.get(id: "anything"))
    }
}
