import SwiftUI

enum DriveType: String, Codable, CaseIterable {
    case ssd = "SSD", hdd = "HDD", unknown = "—"
}

enum HealthStatus: String, Codable {
    case healthy, warning, critical, unknown
    var color: Color {
        switch self {
        case .healthy: .green
        case .warning: .orange
        case .critical: .red
        case .unknown: .secondary
        }
    }
    var symbol: String {
        switch self {
        case .healthy: "checkmark.shield.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.shield.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

struct DiskInfo: Identifiable, Hashable, Codable {
    let id: String
    var model: String
    var serial: String?
    var firmware: String?
    var capacityBytes: Double?
    var driveType: DriveType
    var interface: String
    var smartAvailable: Bool = false
    var smartPassed: Bool?
    var temperature: Double?
    var percentageUsed: Double?
    var availableSpare: Double?
    var spareThreshold: Double?
    var criticalWarning: Int?
    var dataReadTB: Double?
    var dataWrittenTB: Double?
    var powerOnHours: Int?
    var powerCycles: Int?
    var unsafeShutdowns: Int?
    var mediaErrors: Int?
    var diagnostic: String?

    var icon: String { driveType == .ssd ? "internaldrive" : "externaldrive" }
    var size: String {
        guard let capacityBytes else { return "—" }
        return capacityBytes >= 1e12 ? String(format: "%.2f TB", capacityBytes / 1e12)
            : String(format: "%.0f GB", capacityBytes / 1e9)
    }
    var health: HealthStatus {
        if smartPassed == false || (criticalWarning ?? 0) != 0 { return .critical }
        if let spare = availableSpare, let threshold = spareThreshold, spare < threshold { return .critical }
        if (percentageUsed ?? 0) >= 100 { return .critical }
        if (mediaErrors ?? 0) > 0 || (percentageUsed ?? 0) >= 80 || (temperature ?? 0) >= 70 { return .warning }
        guard smartAvailable, smartPassed == true else { return .unknown }
        return .healthy
    }
    var healthLabel: String {
        loc(health == .healthy ? "health.good" : health == .warning ? "health.warning" : health == .critical ? "health.critical" : "health.unknown")
    }
    var healthColor: Color { health.color }
    var remainingEndurance: Double? { percentageUsed.map { max(0, 100 - $0) } }
    var dailyWriteGB: Double? {
        guard let hours = powerOnHours, hours > 0, let written = dataWrittenTB else { return nil }
        return written * 1000 / (Double(hours) / 24)
    }
    var tempColor: Color {
        guard let temperature else { return .secondary }
        return temperature >= 70 ? .red : temperature >= 55 ? .orange : .teal
    }
}

func metric(_ value: Double?, suffix: String = "", decimals: Int = 0) -> String {
    guard let value, value.isFinite else { return "—" }
    return String(format: "%.*f", decimals, value) + suffix
}
func metric(_ value: Int?) -> String { value.map { $0.formatted() } ?? "—" }
