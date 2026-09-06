import Foundation

/// Synthetic examples for documentation; never mixed with live measurements.
enum DemoData {
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
