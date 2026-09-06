import XCTest
@testable import SMARTastic

final class WriteHistoryTests: XCTestCase {
    private func disk(_ total: Double, serial: String? = "test") -> DiskInfo {
        DiskInfo(id: "/dev/disk0", model: "Test", serial: serial, driveType: .ssd, interface: "NVMe", smartAvailable: true, dataWrittenTB: total)
    }
    private var base: Date { ISO8601DateFormatter().date(from: "2026-09-01T12:00:00Z")! }
    private func history() -> WriteHistory { var h = WriteHistory(); h.timeZoneID = "GMT"; return h }

    func testBaselineAndRealElapsedTime() throws {
        var h = history()
        h.record(disk(115), at: base)
        XCTAssertTrue(try XCTUnwrap(h.drives.values.first).days.isEmpty)
        h.record(disk(115.002), at: base.addingTimeInterval(3600))
        let day = try XCTUnwrap(h.drives.values.first?.days.first)
        XCTAssertEqual(day.gb, 2, accuracy: 0.000001)
        XCTAssertEqual(day.seconds, 3600)
        XCTAssertFalse(day.estimated)
    }
    func testMidnightSplitAndLongGap() throws {
        var h = history()
        let midnight = base.addingTimeInterval(12 * 3600)
        h.record(disk(1), at: midnight.addingTimeInterval(-60))
        h.record(disk(1.002), at: midnight.addingTimeInterval(60))
        let days = try XCTUnwrap(h.drives.values.first).days
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].gb, 1, accuracy: 0.000001)
        XCTAssertEqual(days[1].gb, 1, accuracy: 0.000001)
        XCTAssertTrue(days.allSatisfy(\.estimated))
        h.record(disk(1.102), at: midnight.addingTimeInterval(3 * 86400))
        let drive = try XCTUnwrap(h.drives.values.first)
        XCTAssertEqual(drive.days.count, 2)
        XCTAssertEqual(drive.gaps.first!.gb, 100, accuracy: 0.000001)
    }
    func testResetAndStaleSamplesNeverCreateSpikes() throws {
        var h = history()
        h.record(disk(100), at: base)
        h.record(disk(1), at: base.addingTimeInterval(60))
        h.record(disk(200), at: base)
        h.record(disk(1.001), at: base.addingTimeInterval(120))
        XCTAssertEqual(try XCTUnwrap(h.drives.values.first?.days.first).gb, 1, accuracy: 0.000001)
    }
    func testIdentityAndMissingCounters() {
        var h = history()
        h.record(disk(1, serial: nil), at: base)
        h.record(disk(.nan), at: base)
        XCTAssertTrue(h.drives.isEmpty)
        var moved = disk(1); moved = DiskInfo(id: "/dev/disk4", model: moved.model, serial: moved.serial, driveType: .ssd, interface: "NVMe")
        XCTAssertEqual(WriteHistory.key(for: moved), WriteHistory.key(for: disk(1)))
        XCTAssertNotEqual(WriteHistory.key(for: disk(1, serial: "other")), WriteHistory.key(for: disk(1)))
    }
    func testRetentionAndZeroMeasurements() throws {
        var h = history()
        h.record(disk(1), at: base)
        h.record(disk(1), at: base.addingTimeInterval(60))
        XCTAssertEqual(h.drives.values.first?.days.first?.gb, 0)
        h.record(disk(2), at: base.addingTimeInterval(91 * 86400))
        XCTAssertTrue(try XCTUnwrap(h.drives.values.first).days.isEmpty)
    }
    func testDSTDayUsesCalendarBoundaries() throws {
        var h = history(); h.timeZoneID = "Europe/Berlin"
        let start = ISO8601DateFormatter().date(from: "2026-03-28T23:00:00Z")!
        h.record(disk(1), at: start)
        h.record(disk(1.1), at: start.addingTimeInterval(23 * 3600 - 1))
        let day = try XCTUnwrap(h.drives.values.first?.days.first)
        XCTAssertEqual(day.gb, 100, accuracy: 0.000001)
        XCTAssertEqual(day.seconds, 23 * 3600 - 1)
    }
    @MainActor func testPersistenceAndCorruptFileProtection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.json")
        let store = WriteHistoryStore(url: url)
        store.record([disk(1)], at: base)
        let restored = WriteHistoryStore(url: url)
        restored.record([disk(1.001)], at: base.addingTimeInterval(60))
        XCTAssertEqual(try XCTUnwrap(restored.drive(for: disk(1))?.days.first).gb, 1, accuracy: 0.000001)
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: url)
        let broken = WriteHistoryStore(url: url)
        broken.record([disk(2)], at: base)
        XCTAssertTrue(broken.failed)
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }
}
