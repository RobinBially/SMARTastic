import SwiftUI

enum DriveType: String, CaseIterable {
    case ssd = "SSD"
    case hdd = "HDD"
    case unknown = "?"
}

struct DiskInfo: Identifiable, Hashable {
    let id: String
    let model: String
    let serial: String
    let firmware: String
    let size: String
    let driveType: DriveType
    let interface: String

    let smartAvailable: Bool
    let smartPassed: Bool
    let temperature: Double
    let percentageUsed: Double
    let availableSpare: Double
    let dataReadTB: Double
    let dataWrittenTB: Double
    let powerOnHours: Int
    let powerCycles: Int
    let unsafeShutdowns: Int
    let mediaErrors: Int

    // MARK: - Computed

    var icon: String {
        switch driveType {
        case .ssd: "internaldrive"
        case .hdd: "externaldrive"
        case .unknown: "externaldrive"
        }
    }

    var powerOnFormatted: String {
        let d = powerOnHours / 24
        let y = d / 365
        let r = d % 365
        if y > 0 { return locf("power_on_years_days", y, r) }
        return locf("power_on_days", d)
    }

    var dailyWriteGB: Double {
        guard powerOnHours > 0 else { return 0 }
        return (dataWrittenTB * 1000) / (Double(powerOnHours) / 24.0)
    }

    var dailyReadGB: Double {
        guard powerOnHours > 0 else { return 0 }
        return (dataReadTB * 1000) / (Double(powerOnHours) / 24.0)
    }

    var remainingLifeEstimate: String {
        guard percentageUsed > 0, powerOnHours > 0 else { return "\u{2014}" }
        let hoursPerPct = Double(powerOnHours) / percentageUsed
        let remainingHours = hoursPerPct * (100 - percentageUsed)
        let d = Int(remainingHours / 24)
        let y = d / 365
        let r = d % 365
        if y > 0 { return locf("remaining_years_days", y, r) }
        return locf("remaining_days", d)
    }

    var healthScore: Int {
        guard smartAvailable else { return 0 }
        if driveType == .ssd {
            return max(0, min(100, 100 - Int(percentageUsed)))
        }
        if mediaErrors == 0 { return 95 }
        if mediaErrors < 10 { return 60 }
        return 30
    }

    var healthLabel: String {
        guard smartAvailable else { return loc("health.unknown") }
        if driveType == .ssd {
            switch percentageUsed {
            case 0..<10: return loc("health.excellent")
            case 10..<25: return loc("health.very_good")
            case 25..<50: return loc("health.good")
            case 50..<75: return loc("health.acceptable")
            case 75..<90: return loc("health.warning")
            default: return loc("health.critical")
            }
        }
        if mediaErrors == 0 { return loc("health.good") }
        if mediaErrors < 10 { return loc("health.warning") }
        return loc("health.critical")
    }

    var healthColor: Color {
        let s = healthScore
        if s >= 75 { return Color.green }
        if s >= 40 { return Color.orange }
        return Color.red
    }

    var tempLabel: String {
        guard smartAvailable else { return "\u{2014}" }
        switch temperature {
        case ..<40: return loc("temp.very_cool")
        case 40..<55: return loc("temp.normal")
        case 55..<70: return loc("temp.warm")
        default: return loc("temp.hot")
        }
    }

    var tempColor: Color {
        guard smartAvailable else { return .gray }
        switch temperature {
        case ..<40: return Color.teal
        case 40..<55: return Color.green
        case 55..<70: return Color.orange
        default: return Color.red
        }
    }
}
