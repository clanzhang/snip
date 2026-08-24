import XCTest
@testable import Snip

final class EventFormatterTests: XCTestCase {

    private func makeClipboardEvent(changeCount: Int, types: [String], appName: String, bundleId: String, pid: Int32 = 1234) -> ClipboardEvent {
        ClipboardEvent(
            timestamp: Date(),
            changeCount: changeCount,
            types: types,
            isText: types.contains("public.utf8-plain-text"),
            isImage: types.contains("public.png") || types.contains("public.tiff"),
            isFileURL: types.contains("public.file-url"),
            appName: appName,
            bundleId: bundleId,
            pid: pid
        )
    }

    private func makeKeyboardEvent(type: KeyEventType, keyCode: Int64, modifiers: String, combo: String?, appName: String, bundleId: String, pid: Int32 = 1234) -> KeyboardEvent {
        KeyboardEvent(
            timestamp: Date(),
            type: type,
            keyCode: keyCode,
            modifiers: modifiers,
            combo: combo,
            repeat: false,
            appName: appName,
            bundleId: bundleId,
            pid: pid,
            char: nil
        )
    }

    // MARK: - Plain mode

    func testPlainClipboardEvent() {
        let f = EventFormatter(mode: .plain, theme: .none)
        let event = makeClipboardEvent(changeCount: 102, types: ["public.utf8-plain-text"], appName: "Notes", bundleId: "com.apple.Notes")
        let line = f.clipboardEvent(event)
        XCTAssertTrue(line.contains("📋"))
        XCTAssertTrue(line.contains("剪贴板更新"))
        XCTAssertTrue(line.contains("Notes"))
        XCTAssertTrue(line.contains("文本"))
    }

    func testPlainClipboardEventImage() {
        let f = EventFormatter(mode: .plain, theme: .none)
        let event = makeClipboardEvent(changeCount: 102, types: ["public.png"], appName: "Preview", bundleId: "com.apple.Preview")
        let line = f.clipboardEvent(event)
        XCTAssertTrue(line.contains("图片"))
    }

    func testPlainKeyboardEvent() {
        let f = EventFormatter(mode: .plain, theme: .none)
        let event = makeKeyboardEvent(type: .keyDown, keyCode: 8, modifiers: "cmd", combo: "cmd+c", appName: "Notes", bundleId: "com.apple.Notes")
        let line = f.keyboardEvent(event)
        XCTAssertTrue(line.contains("⌨️"))
        XCTAssertTrue(line.contains("Command+C"))
        XCTAssertTrue(line.contains("Notes"))
    }

    // MARK: - Verbose mode

    func testVerboseClipboardEvent() {
        let f = EventFormatter(mode: .verbose, theme: .none)
        let event = makeClipboardEvent(changeCount: 102, types: ["public.utf8-plain-text"], appName: "Notes", bundleId: "com.apple.Notes")
        let line = f.clipboardEvent(event)
        XCTAssertTrue(line.contains("changeCount=102"))
        XCTAssertTrue(line.contains("bundle=com.apple.Notes"))
    }

    func testVerboseKeyboardEvent() {
        let f = EventFormatter(mode: .verbose, theme: .none)
        let event = makeKeyboardEvent(type: .keyDown, keyCode: 8, modifiers: "cmd", combo: "cmd+c", appName: "Notes", bundleId: "com.apple.Notes")
        let line = f.keyboardEvent(event)
        XCTAssertTrue(line.contains("keyCode=8"))
        XCTAssertTrue(line.contains("modifiers=cmd"))
        XCTAssertTrue(line.contains("bundle=com.apple.Notes"))
    }

    // MARK: - JSON mode

    func testJSONClipboardEvent() {
        let f = EventFormatter(mode: .json, theme: .none)
        let event = makeClipboardEvent(changeCount: 102, types: ["public.utf8-plain-text"], appName: "Notes", bundleId: "com.apple.Notes")
        let line = f.clipboardEvent(event)
        let data = line.data(using: String.Encoding.utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["type"] as? String, "clipboard_changed")
        XCTAssertEqual(obj["change_count"] as? Int, 102)
        XCTAssertEqual(obj["app"] as? String, "Notes")
    }

    func testJSONKeyboardEvent() {
        let f = EventFormatter(mode: .json, theme: .none)
        let event = makeKeyboardEvent(type: .keyDown, keyCode: 8, modifiers: "cmd", combo: "cmd+c", appName: "Notes", bundleId: "com.apple.Notes")
        let line = f.keyboardEvent(event)
        let data = line.data(using: String.Encoding.utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["type"] as? String, "keyDown")
        XCTAssertEqual(obj["combo"] as? String, "cmd+c")
    }

    // MARK: - Bundle ID shortening

    func testBundleIdShortening() {
        let f = EventFormatter(mode: .plain, theme: .none)
        let event = makeClipboardEvent(changeCount: 1, types: ["public.utf8-plain-text"], appName: "Google Chrome", bundleId: "com.google.Chrome", pid: 1)
        let line = f.clipboardEvent(event)
        XCTAssertTrue(line.contains("Google Chrome"))
    }

    func testUnknownAppFallback() {
        let f = EventFormatter(mode: .plain, theme: .none)
        let event = makeClipboardEvent(changeCount: 1, types: ["public.utf8-plain-text"], appName: "unknown", bundleId: "com.unknown.xyz", pid: 1)
        let line = f.clipboardEvent(event)
        XCTAssertFalse(line.isEmpty)
    }
}