import Foundation
import CoreFoundation

/// Interpret smartctl's JSON, never its locale-dependent human-readable columns.
enum SmartParser {
    static func parse(_ data: Data, device: String, fallback: DiskInfo? = nil) throws -> DiskInfo {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SmartCtlError.commandFailed(loc("error.invalid_json"))
        }
        var disk = fallback ?? DiskInfo(id: device, model: device, driveType: .unknown, interface: "—")
        disk.model = json["model_name"] as? String ?? json["product"] as? String ?? disk.model
        disk.serial = nonempty(json["serial_number"]) ?? disk.serial
        disk.firmware = nonempty(json["firmware_version"]) ?? disk.firmware
        disk.capacityBytes = number((json["user_capacity"] as? [String: Any])?["bytes"]) ?? number(json["nvme_total_capacity"]) ?? disk.capacityBytes
        let dev = json["device"] as? [String: Any]
        disk.interface = dev?["protocol"] as? String ?? disk.interface
        let nvme = json["nvme_smart_health_information_log"] as? [String: Any]
        let table = (json["ata_smart_attributes"] as? [String: Any])?["table"] as? [[String: Any]] ?? []
        if nvme != nil || disk.interface == "NVMe" { disk.driveType = .ssd }
        else if let rotation = number(json["rotation_rate"]) { disk.driveType = rotation == 0 ? .ssd : .hdd }
        disk.smartPassed = (json["smart_status"] as? [String: Any])?["passed"] as? Bool
        disk.smartAvailable = disk.smartPassed != nil || nvme != nil || !table.isEmpty
        func raw(_ id: Int) -> Double? {
            number((table.first { ($0["id"] as? Int) == id }?["raw"] as? [String: Any])?["value"])
        }
        func integer(_ value: Double?) -> Int? {
            guard let value, value >= 0, value < Double(Int.max) else { return nil }
            return Int(value)
        }
        disk.temperature = number((json["temperature"] as? [String: Any])?["current"]) ?? number(nvme?["temperature"])
        // Attribute 194's raw integer can pack min/max values. Only use smartctl's decoded temperature.
        disk.percentageUsed = number(nvme?["percentage_used"])
        disk.availableSpare = number(nvme?["available_spare"])
        disk.spareThreshold = number(nvme?["available_spare_threshold"])
        disk.criticalWarning = integer(number(nvme?["critical_warning"]))
        // One NVMe data unit is 1,000 × 512 bytes (NVMe specification).
        disk.dataReadTB = number(nvme?["data_units_read"]).map { $0 * 512_000 / 1e12 }
        disk.dataWrittenTB = number(nvme?["data_units_written"]).map { $0 * 512_000 / 1e12 }
        disk.powerOnHours = integer(number((json["power_on_time"] as? [String: Any])?["hours"]) ?? number(nvme?["power_on_hours"]) ?? raw(9))
        disk.powerCycles = integer(number(json["power_cycle_count"]) ?? number(nvme?["power_cycles"]) ?? raw(12))
        disk.unsafeShutdowns = integer(number(nvme?["unsafe_shutdowns"]))
        if let errors = integer(number(nvme?["media_errors"])) { disk.mediaErrors = errors }
        else {
            // ATA IDs are vendor-specific: e.g. 198 can mean Host_Reads_GiB.
            let errorNames: Set<String> = ["Reallocated_Sector_Ct", "Reallocated_Sector_Count", "Retired_Block_Count", "Current_Pending_Sector", "Offline_Uncorrectable"]
            let counts = table.filter { errorNames.contains($0["name"] as? String ?? "") }
                .compactMap { number(($0["raw"] as? [String: Any])?["value"]) }
            disk.mediaErrors = counts.isEmpty ? nil : integer(counts.reduce(0, +))
        }
        let messages = (json["smartctl"] as? [String: Any])?["messages"] as? [[String: Any]] ?? []
        disk.diagnostic = messages.compactMap { $0["string"] as? String }.joined(separator: "\n")
        if disk.diagnostic?.isEmpty == true { disk.diagnostic = nil }
        return disk
    }

    static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
        let number = value.doubleValue
        return number.isFinite && number >= 0 ? number : nil
    }
    private static func nonempty(_ value: Any?) -> String? {
        guard let text = value as? String, !text.trimmingCharacters(in: .whitespaces).isEmpty, text != "-" else { return nil }
        return text
    }
}
