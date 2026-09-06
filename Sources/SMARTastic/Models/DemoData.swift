import Foundation

/// Synthetic examples for documentation; never mixed with live measurements.
enum DemoData {
    @MainActor static func seedHistory(_ store: WriteHistoryStore, now: Date = .now) {
        let calendar = store.history.calendar
        let today = calendar.startOfDay(for: now)
        var disk = disks[0]
        var total = 20.0
        // Deliberately leave two gaps to demonstrate honest missing-data handling.
        for offset in -89...0 {
            if offset == -4 || offset == -3 { continue }
            let start = calendar.date(byAdding: .day, value: offset, to: today)!
            let end = offset == 0 ? now : calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
            disk.dataWrittenTB = total
            store.record([disk], at: start)
            total += (Double((offset + 90) * 17 % 53) + 8 + (offset == -5 ? 85 : 0)) / 1000
            disk.dataWrittenTB = total
            store.record([disk], at: end)
        }
    }
    static let disks: [DiskInfo] = [
        DiskInfo(id: "demo-nvme", model: "Samsung SSD 990 PRO 2TB", serial: "DEMO-NVME-001", firmware: "4B2QJXD7",
                 capacityBytes: 2e12, driveType: .ssd, interface: "NVMe", smartAvailable: true, smartPassed: true,
                 temperature: 39, percentageUsed: 7, availableSpare: 100, spareThreshold: 10, criticalWarning: 0,
                 dataReadTB: 48.6, dataWrittenTB: 32.4, powerOnHours: 6840, powerCycles: 426, unsafeShutdowns: 3, mediaErrors: 0),
        DiskInfo(id: "demo-hdd", model: "WDC Red Plus 4TB", serial: "DEMO-ATA-002", firmware: "83.00A83",
                 capacityBytes: 4e12, driveType: .hdd, interface: "ATA", smartAvailable: true, smartPassed: true,
                 temperature: 34, powerOnHours: 18240, powerCycles: 812, mediaErrors: 8),
        DiskInfo(id: "demo-usb", model: "Portable SSD", capacityBytes: 1e12, driveType: .ssd, interface: "USB")
    ]
}
