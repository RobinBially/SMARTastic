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
        if y > 0 { return "\(y) J. \(r) T." }
        return "\(d) Tage"
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
        if y > 0 { return "\u{2248}\(y) J. \(r) T." }
        return "\u{2248}\(d) Tage"
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
        guard smartAvailable else { return "Unbekannt" }
        if driveType == .ssd {
            switch percentageUsed {
            case 0..<10: return "Ausgezeichnet"
            case 10..<25: return "Sehr gut"
            case 25..<50: return "Gut"
            case 50..<75: return "Akzeptabel"
            case 75..<90: return "Achtung"
            default: return "Kritisch"
            }
        }
        if mediaErrors == 0 { return "Gut" }
        if mediaErrors < 10 { return "Achtung" }
        return "Kritisch"
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
        case ..<40: return "Sehr kühl"
        case 40..<55: return "Normal"
        case 55..<70: return "Warm"
        default: return "Hei\u{00DF}"
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
