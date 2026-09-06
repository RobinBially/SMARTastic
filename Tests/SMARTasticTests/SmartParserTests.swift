import XCTest
@testable import SMARTastic

final class SmartParserTests: XCTestCase {
    private func parse(_ json: String, device: String = "/dev/disk42") throws -> DiskInfo {
        try SmartParser.parse(Data(json.utf8), device: device)
    }
    func testNVMeUnitsAndPartialCommandFailure() throws {
        let disk = try parse(#"{"model_name":"Test SSD","device":{"protocol":"NVMe"},"smartctl":{"exit_status":4,"messages":[{"string":"Optional error log unavailable"}]},"smart_status":{"passed":true},"user_capacity":{"bytes":2000000000000},"nvme_smart_health_information_log":{"percentage_used":7,"data_units_written":2000000,"data_units_read":4000000,"temperature":39,"power_on_hours":1000}}"#)
        XCTAssertEqual(disk.dataWrittenTB!, 1.024, accuracy: 0.000001)
        XCTAssertEqual(disk.dataReadTB!, 2.048, accuracy: 0.000001)
        XCTAssertEqual(disk.size, "2.00 TB")
        XCTAssertEqual(try XCTUnwrap(disk.writtenGBPer24PowerOnHours), 24.576, accuracy: 0.000001)
        XCTAssertEqual(disk.temperature, 39)
        XCTAssertEqual(disk.health, .healthy)
        XCTAssertNotNil(disk.diagnostic)
    }
    func testATACountersUseRawValuesAndDecodedTemperature() throws {
        let disk = try parse(#"{"rotation_rate":7200,"temperature":{"current":32},"smart_status":{"passed":true},"ata_smart_attributes":{"table":[{"id":9,"value":99,"raw":{"value":18342}},{"id":12,"value":100,"raw":{"value":654}},{"id":194,"value":118,"raw":{"value":9999999}},{"id":5,"name":"Reallocated_Sector_Ct","raw":{"value":2}},{"id":197,"name":"Current_Pending_Sector","raw":{"value":3}},{"id":198,"name":"Offline_Uncorrectable","raw":{"value":1}}]}}"#)
        XCTAssertEqual(disk.powerOnHours, 18342)
        XCTAssertEqual(disk.powerCycles, 654)
        XCTAssertEqual(disk.temperature, 32)
        XCTAssertEqual(disk.mediaErrors, 6)
        XCTAssertEqual(disk.driveType, .hdd)
        XCTAssertEqual(disk.health, .warning)
        XCTAssertNil(disk.percentageUsed)
        XCTAssertNil(disk.dataWrittenTB)
    }
    func testVendorReadCounterIsNotMediaErrors() throws {
        let disk = try parse(#"{"smart_status":{"passed":true},"ata_smart_attributes":{"table":[{"id":5,"name":"Reallocated_Sector_Ct","raw":{"value":0}},{"id":198,"name":"Host_Reads_GiB","raw":{"value":100}}]}}"#)
        XCTAssertEqual(disk.mediaErrors, 0)
        XCTAssertEqual(disk.health, .healthy)
    }
    func testFailureOverridesLowWear() throws {
        let disk = try parse(#"{"smart_status":{"passed":false},"nvme_smart_health_information_log":{"percentage_used":0}}"#)
        XCTAssertEqual(disk.health, .critical)
    }
    func testCriticalWarningAndSpareThreshold() throws {
        XCTAssertEqual(try parse(#"{"nvme_smart_health_information_log":{"critical_warning":1}}"#).health, .critical)
        XCTAssertEqual(try parse(#"{"nvme_smart_health_information_log":{"available_spare":3,"available_spare_threshold":10}}"#).health, .critical)
    }
    func testUnknownValuesDoNotBecomeHealthyZeros() throws {
        let disk = try parse(#"{"model_name":"USB SSD","smart_support":{"available":false}}"#)
        XCTAssertFalse(disk.smartAvailable)
        XCTAssertEqual(disk.health, .unknown)
        XCTAssertNil(disk.temperature)
        XCTAssertNil(disk.mediaErrors)
        XCTAssertNil(disk.remainingEndurance)
        XCTAssertNil(disk.writtenGBPer24PowerOnHours)
    }
    func testMissingSerialsHaveSeparateDeviceIdentities() throws {
        XCTAssertNotEqual(try parse("{}", device: "/dev/disk21").id, try parse("{}", device: "/dev/disk22").id)
    }
    func testWearAbove100AndZeroHours() throws {
        let disk = try parse(#"{"nvme_smart_health_information_log":{"percentage_used":255,"power_on_hours":0,"data_units_written":0}}"#)
        XCTAssertEqual(disk.remainingEndurance, 0)
        XCTAssertEqual(disk.health, .critical)
        XCTAssertEqual(disk.powerOnHours, 0)
        XCTAssertNil(disk.writtenGBPer24PowerOnHours)
    }
    func testInvalidAndBooleanMetrics() throws {
        XCTAssertThrowsError(try parse("not json"))
        let disk = try parse(#"{"nvme_smart_health_information_log":{"percentage_used":true,"power_on_hours":1e30,"temperature":-100}}"#)
        XCTAssertNil(disk.percentageUsed)
        XCTAssertNil(disk.powerOnHours)
        XCTAssertNil(disk.temperature)
    }
    func testReportOmitsSerialNumbersAndPreservesSampleTime() throws {
        let date = Date(timeIntervalSince1970: 1000)
        let report = try ReportDocument(disks: DemoData.disks, sampledAt: date, demo: true, warning: "stale")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: report.data) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        XCTAssertEqual(json["demo"] as? Bool, true)
        XCTAssertEqual(json["sampledAt"] as? String, "1970-01-01T00:16:40Z")
        XCTAssertEqual(json["warning"] as? String, "stale")
        let disks = try XCTUnwrap(json["disks"] as? [[String: Any]])
        XCTAssertTrue(disks.allSatisfy { $0["serial"] == nil })
    }
    func testLargeOutputDoesNotDeadlock() throws {
        let result = try CommandRunner.run("/usr/bin/awk", ["BEGIN { for (i=0; i<20000; i++) print \"abcdefghij\" }"])
        XCTAssertEqual(result.status, 0)
        XCTAssertGreaterThan(result.data.count, 200000)
    }
    func testCommandTimeout() {
        let start = Date()
        XCTAssertThrowsError(try CommandRunner.run("/bin/sleep", ["5"], timeout: 0.1))
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
    }
}

@MainActor
final class AppModelTests: XCTestCase {
    private func finish(_ model: AppModel) async throws {
        for _ in 0..<100 where model.isLoading { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(model.isLoading)
    }
    func testSelectionReconcilesAfterDisconnect() async throws {
        let model = AppModel(isDemo: false, scanner: { ScanResult(disks: [DemoData.disks[1]], warning: nil) })
        model.disks = DemoData.disks
        model.selectedDiskID = DemoData.disks[0].id
        model.refresh()
        try await finish(model)
        XCTAssertEqual(model.selectedDiskID, DemoData.disks[1].id)
        XCTAssertNotNil(model.lastRefreshed)
    }
    func testFailurePreservesSnapshotAndExposesError() async throws {
        let model = AppModel(isDemo: false, scanner: { throw SmartCtlError.commandFailed("test failure") })
        model.disks = DemoData.disks
        model.selectedDiskID = DemoData.disks[0].id
        model.lastRefreshed = Date(timeIntervalSince1970: 123)
        model.refresh()
        try await finish(model)
        XCTAssertEqual(model.disks, DemoData.disks)
        XCTAssertEqual(model.lastRefreshed, Date(timeIntervalSince1970: 123))
        XCTAssertEqual(model.error, "test failure")
    }
    func testEmptyScanClearsSelection() async throws {
        let model = AppModel(isDemo: false, scanner: { ScanResult(disks: [], warning: nil) })
        model.disks = DemoData.disks
        model.selectedDiskID = DemoData.disks[0].id
        model.refresh()
        try await finish(model)
        XCTAssertNil(model.selectedDiskID)
        XCTAssertTrue(model.disks.isEmpty)
    }
    func testConcurrentRefreshIsSuppressed() async throws {
        actor Counter {
            var calls = 0
            func scan() async throws -> ScanResult {
                calls += 1
                try await Task.sleep(nanoseconds: 50_000_000)
                return ScanResult(disks: [], warning: nil)
            }
        }
        let counter = Counter()
        let model = AppModel(isDemo: false, scanner: { try await counter.scan() })
        model.refresh(); model.refresh()
        try await finish(model)
        let calls = await counter.calls
        XCTAssertEqual(calls, 1)
    }
    func testLiveScanWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["SMARTASTIC_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set SMARTASTIC_LIVE_TEST=1 to run the hardware integration check.")
        }
        let result = try await SmartCtlService.shared.scan()
        XCTAssertFalse(result.disks.isEmpty)
        XCTAssertTrue(result.disks.contains { $0.model.contains("APPLE") })
        XCTAssertTrue(result.disks.contains { $0.smartAvailable })
    }
}
