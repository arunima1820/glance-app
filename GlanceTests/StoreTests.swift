import XCTest
import SwiftData
@testable import Glance

// MARK: - GroupContainerStub
/// FileManager whose App Group container is a chosen URL (or nil), so the store-directory
/// logic runs against a throwaway folder instead of the real group container.
private final class GroupContainerStub: FileManager, @unchecked Sendable {
    private let groupURL: URL?

    init(groupURL: URL?) {
        self.groupURL = groupURL
        super.init()
    }

    override func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? {
        groupURL
    }
}

// MARK: - StoreTests
// Covers: GlanceStore.swift (makeContainer(inMemory:), appGroupIdentifier,
// ensureStoreDirectoryExists(fileManager:)) and the Theme.steps cascade rule in Theme.swift.

final class StoreTests: XCTestCase {

    private var tempRoot: URL?

    override func tearDown() async throws {
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
        tempRoot = nil
    }

    private func makeTempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "GlanceStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        tempRoot = url
        return url
    }

    // MARK: Container

    func testInMemoryContainerStartsEmpty() throws {
        let context = ModelContext(try GlanceStore.makeContainer(inMemory: true))
        XCTAssertTrue(try context.fetch(FetchDescriptor<Theme>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Step>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<GlanceCategory>()).isEmpty)
    }

    // MARK: Relationships

    func testThemeWithStepsPersistsRelationship() throws {
        let context = ModelContext(try GlanceStore.makeContainer(inMemory: true))
        let theme = Theme(name: "With steps", colorToken: "sky")
        theme.steps = [Step(text: "Step two", sortOrder: 1), Step(text: "Step one", sortOrder: 0)]
        context.insert(theme)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Theme>()).first
        XCTAssertEqual(fetched?.orderedSteps.map(\.text), ["Step one", "Step two"])
        XCTAssertTrue(fetched?.steps.allSatisfy { $0.theme === fetched } ?? false)
    }

    func testDeletingThemeCascadesToSteps() throws {
        let context = ModelContext(try GlanceStore.makeContainer(inMemory: true))
        let theme = Theme(name: "Cascade test", colorToken: "slate")
        theme.steps = [Step(text: "Should be deleted", sortOrder: 0)]
        context.insert(theme)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Step>()).count, 1)

        context.delete(theme)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Theme>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Step>()).count, 0)
    }

    // MARK: App Group identifier

    func testAppGroupIdentifierHasGroupPrefix() {
        XCTAssertTrue(GlanceStore.appGroupIdentifier.hasPrefix("group."),
                      "App Group ID must start with 'group.': \(GlanceStore.appGroupIdentifier)")
    }

    // MARK: Store directory

    func testEnsureStoreDirectoryCreatesApplicationSupportAndIsIdempotent() throws {
        let root = makeTempRoot()
        let fileManager = GroupContainerStub(groupURL: root)
        try GlanceStore.ensureStoreDirectoryExists(fileManager: fileManager)

        var isDir: ObjCBool = false
        let path = root.appending(path: "Library/Application Support").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
        XCTAssertNoThrow(try GlanceStore.ensureStoreDirectoryExists(fileManager: fileManager))
    }

    func testEnsureStoreDirectoryIsNoOpWithoutGroupContainer() {
        let fileManager = GroupContainerStub(groupURL: nil)
        XCTAssertNoThrow(try GlanceStore.ensureStoreDirectoryExists(fileManager: fileManager))
    }
}
