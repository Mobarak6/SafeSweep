import XCTest
@testable import StorageCleaner

final class DuplicateFinderTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, _ data: Data) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    func testFindsIdenticalFilesOnly() throws {
        let big = Data((0..<200_000).map { UInt8($0 % 251) })
        var sameStartDifferentEnd = big
        sameStartDifferentEnd[199_999] ^= 0xFF

        _ = try write("a/photo.jpg", big)
        _ = try write("b/photo copy.jpg", big)
        _ = try write("c/almost.jpg", sameStartDifferentEnd)
        _ = try write("small1.txt", Data("hello".utf8))
        _ = try write("small2.txt", Data("hello".utf8))

        let groups = DuplicateFinder.find(in: [root], minimumSize: 1) { _ in }

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.size, 200_000)
        XCTAssertEqual(Set(groups.first!.files.map(\.url.lastPathComponent)), ["photo.jpg", "photo copy.jpg"])
    }

    func testSkipsToolFoldersHardLinksAndSmallFiles() throws {
        let data = Data(repeating: 7, count: 5_000)
        let original = try write("doc.pdf", data)
        _ = try write("node_modules/pkg/doc.pdf", data)
        _ = try write(".git/objects/doc.pdf", data)
        try FileManager.default.linkItem(at: original, to: root.appendingPathComponent("hardlink.pdf"))

        XCTAssertTrue(DuplicateFinder.find(in: [root], minimumSize: 1) { _ in }.isEmpty)
        XCTAssertTrue(DuplicateFinder.find(in: [root], minimumSize: 10_000) { _ in }.isEmpty)
    }
}
