@testable import Odyssey
import XCTest

final class VoiceRecordingStoreTests: XCTestCase {
    private var root: URL!
    private var store: VoiceRecordingStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceRecordingStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = VoiceRecordingStore(directory: root.appendingPathComponent("VoiceRecordings", isDirectory: true))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeTempRecording(ext: String = "m4a") throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try Data("fake audio".utf8).write(to: url)
        return url
    }

    func testImportMovesFileIntoStore() throws {
        let source = try makeTempRecording()

        let filename = try store.importRecording(from: source)

        XCTAssertTrue(filename.hasSuffix(".m4a"))
        XCTAssertTrue(store.exists(filename))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path), "Source should be consumed")
        XCTAssertEqual(try Data(contentsOf: store.url(for: filename)), Data("fake audio".utf8))
    }

    func testImportKeepsExtension() throws {
        let filename = try store.importRecording(from: try makeTempRecording(ext: "caf"))
        XCTAssertTrue(filename.hasSuffix(".caf"))
    }

    func testDeleteRemovesFileAndToleratesMissing() throws {
        let filename = try store.importRecording(from: try makeTempRecording())

        store.delete(filename)
        XCTAssertFalse(store.exists(filename))
        store.delete(filename) // already gone: no crash
    }

    func testDeleteRecordingsForEntry() throws {
        let first = try store.importRecording(from: try makeTempRecording())
        let second = try store.importRecording(from: try makeTempRecording())
        let entry = DailyEntry()
        entry.voiceAudioFilenames = [first, second]

        store.deleteRecordings(for: entry)

        XCTAssertFalse(store.exists(first))
        XCTAssertFalse(store.exists(second))
    }

    func testURLStaysInsideStoreDirectory() {
        let url = store.url(for: "../../escape.m4a")
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, store.directory.standardizedFileURL)
        XCTAssertEqual(url.lastPathComponent, "escape.m4a")
    }
}
