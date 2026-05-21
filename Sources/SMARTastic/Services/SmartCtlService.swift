import Foundation

actor SmartCtlService {
    static let shared = SmartCtlService()
    private let smartctl = "/opt/homebrew/bin/smartctl"

    private init() {}

    func scan() throws -> [DiskInfo] {
        var bySerial: [String: DiskInfo] = [:]

        // 1) NVMe via smartctl --scan (IOService paths)
        if let scan = try? run(smartctl, "--scan") {
            for line in scan.components(separatedBy: .newlines) where line.contains("NVMe") {
                if let range = line.range(of: " -d nvme") {
                    let path = String(line[..<range.lowerBound])
                    if let info = parseNVMe(device: path) {
                        if !info.model.contains("APPLE") {
                            bySerial[info.serial] = info
                        }
                    }
                }
            }
        }

        // 2) External physical disks via diskutil
        for dev in findPhysicalDisks() {
            if let info = readDisk(device: dev) {
                bySerial[info.serial] = info
            }
        }

        return bySerial.values
            .filter { !$0.model.contains("APPLE") }
            .sorted { $0.model < $1.model }
    }

    // MARK: - Disk Discovery

    private func findPhysicalDisks() -> [String] {
        var disks: [String] = []
        for i in 0...20 {
            let dev = "/dev/disk\(i)"
            guard FileManager.default.isReadableFile(atPath: dev) else { continue }
            guard let info = try? run("/usr/sbin/diskutil", "info", "-plist", dev) else { continue }
            guard info.contains("<key>Virtual</key>") && info.contains("<false/>") else { continue }
            disks.append(dev)
        }
        return disks
    }

    // MARK: - Disk Reader

    private func readDisk(device: String) -> DiskInfo? {
        if let output = try? run(smartctl, "-a", device) {
            if output.contains("NVMe") {
                return parseNVMe(device: device, output: output)
            }
            if output.contains("ATA") || output.contains("Device Model:") {
                return parseATA(device: device, output: output)
            }
        }
        return basicInfo(device: device)
    }

    private func basicInfo(device: String) -> DiskInfo? {
        let ident = device.components(separatedBy: "/").last ?? "?"
        let output = try? run("/usr/sbin/diskutil", "info", "-plist", device)
        guard let data = output?.data(using: .utf8),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return DiskInfo(
                id: ident, model: "Unknown", serial: ident, firmware: "-",
                size: "?", driveType: .unknown, interface: "?",
                smartAvailable: false, smartPassed: false,
                temperature: 0, percentageUsed: 0, availableSpare: 0,
                dataReadTB: 0, dataWrittenTB: 0, powerOnHours: 0,
                powerCycles: 0, unsafeShutdowns: 0, mediaErrors: 0
            )
        }

        let model = (dict["MediaName"] as? String) ?? "Unknown"
        let serial = (dict["SerialNumber"] as? String) ?? ident
        let totalSize = (dict["TotalSize"] as? UInt64) ?? 0
        let size = formatBytes("\(totalSize)")

        return DiskInfo(
            id: serial,
            model: model,
            serial: serial,
            firmware: "-",
            size: size,
            driveType: .hdd,
            interface: "USB",
            smartAvailable: false,
            smartPassed: false,
            temperature: 0,
            percentageUsed: 0,
            availableSpare: 0,
            dataReadTB: 0,
            dataWrittenTB: 0,
            powerOnHours: 0,
            powerCycles: 0,
            unsafeShutdowns: 0,
            mediaErrors: 0
        )
    }

    // MARK: - NVMe Parser

    private func parseNVMe(device: String) -> DiskInfo? {
        guard let output = try? run(smartctl, "-a", device) else { return nil }
        return parseNVMe(device: device, output: output)
    }

    private func parseNVMe(device: String, output: String) -> DiskInfo {
        let info = parseKeyValues(output)
        let smart = parseSmartSection(output, marker: "SMART/Health Information")

        let model = info["Model Number"] ?? "Unknown"
        let serial = info["Serial Number"] ?? "-"
        let fw = info["Firmware Version"] ?? "-"
        let size = formatBytes(info["Total NVM Capacity"] ?? "-")

        func d(_ key: String) -> Double? {
            if let v = smart[key] ?? info[key] {
                let s = v.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression).replacingOccurrences(of: ",", with: ".")
                return Double(s)
            }
            return nil
        }
        func i(_ key: String) -> Int? {
            if let v = smart[key] ?? info[key] {
                let s = v.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                return Int(s)
            }
            return nil
        }

        return DiskInfo(
            id: serial,
            model: model,
            serial: serial,
            firmware: fw,
            size: size,
            driveType: .ssd,
            interface: "NVMe",
            smartAvailable: true,
            smartPassed: output.contains("SMART overall-health self-assessment test result: PASSED"),
            temperature: d("Temperature") ?? 0,
            percentageUsed: d("Percentage Used") ?? 0,
            availableSpare: d("Available Spare") ?? 100,
            dataReadTB: parseDataUnits(smart["Data Units Read"] ?? "0"),
            dataWrittenTB: parseDataUnits(smart["Data Units Written"] ?? "0"),
            powerOnHours: i("Power On Hours") ?? 0,
            powerCycles: i("Power Cycles") ?? 0,
            unsafeShutdowns: i("Unsafe Shutdowns") ?? 0,
            mediaErrors: i("Media and Data Integrity Errors") ?? 0
        )
    }

    // MARK: - ATA Parser

    private func parseATA(device: String, output: String) -> DiskInfo {
        let info = parseKeyValues(output)
        let attrs = parseATAattributes(output)

        let model = info["Device Model"] ?? info["Model Number"] ?? "Unknown"
        let serial = info["Serial Number"] ?? "-"
        let fw = info["Firmware Version"] ?? info["Revision"] ?? "-"
        let sizeRaw = info["User Capacity"] ?? info["Total NVM Capacity"] ?? "-"

        let rotation = info["Rotation Rate"] ?? ""
        let isHDD = rotation.contains("rpm")
        let driveType: DriveType = isHDD ? .hdd : .ssd
        let interface = info["SAT"] ?? info["ATA Version"] ?? "ATA"

        let smartPassed = output.contains("SMART overall-health self-assessment test result: PASSED")
            || output.contains("SMART Health Status: OK")

        let tempRaw = attrs["194"]?.value ?? attrs["Temperature_Celsius"]?.value ?? "0"
        let temp = Double(tempRaw) ?? 0

        let pohRaw = attrs["9"]?.value ?? attrs["Power_On_Hours"]?.value ?? "0"
        let poh = Int(pohRaw) ?? 0

        let cyclesRaw = attrs["12"]?.value ?? attrs["Power_Cycle_Count"]?.value ?? "0"
        let cycles = Int(cyclesRaw) ?? 0

        let reallocRaw = attrs["5"]?.raw ?? attrs["Reallocated_Sector_Ct"]?.raw ?? "0"
        let realloc = Int(reallocRaw) ?? 0

        let pendingRaw = attrs["197"]?.raw ?? attrs["Current_Pending_Sector"]?.raw ?? "0"
        let pending = Int(pendingRaw) ?? 0

        let mediaErrors = realloc + pending
        let size = formatBytes(sizeRaw)

        return DiskInfo(
            id: serial,
            model: model,
            serial: serial,
            firmware: fw,
            size: size,
            driveType: driveType,
            interface: interface,
            smartAvailable: true,
            smartPassed: smartPassed,
            temperature: temp,
            percentageUsed: 0,
            availableSpare: 100,
            dataReadTB: 0,
            dataWrittenTB: 0,
            powerOnHours: poh,
            powerCycles: cycles,
            unsafeShutdowns: 0,
            mediaErrors: mediaErrors
        )
    }

    // MARK: - ATA Attribute Parser

    private struct ATAAttr {
        let name: String
        let value: String
        let worst: String
        let threshold: String
        let raw: String
    }

    private func parseATAattributes(_ text: String) -> [String: ATAAttr] {
        var attrs: [String: ATAAttr] = [:]
        guard let headerRange = text.range(of: "Vendor Specific SMART Attributes with Thresholds") else { return attrs }

        let slice = text[headerRange.upperBound...]
        guard let firstNewline = slice.firstIndex(of: "\n") else { return attrs }
        let block = text[text.index(after: firstNewline)...]
        guard let footerRange = block.range(of: "\n\n") else { return attrs }
        let attrBlock = block[..<footerRange.lowerBound]

        for line in attrBlock.components(separatedBy: .newlines) {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 10, let _ = Int(parts[0]) else { continue }
            let id = String(parts[0])
            let name = parts[1...].dropLast(5).joined(separator: " ")
            let val = String(parts[parts.count - 5])
            let worst = String(parts[parts.count - 4])
            let thresh = String(parts[parts.count - 3])
            let raw = String(parts[parts.count - 1])
            let attr = ATAAttr(name: name, value: val, worst: worst, threshold: thresh, raw: raw)
            attrs[id] = attr
            attrs[name] = attr
        }
        return attrs
    }

    // MARK: - Shared Parsers

    private func parseKeyValues(_ text: String) -> [String: String] {
        var dict: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces)
                var val = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if val.hasPrefix("[") { val = String(val.dropFirst()) }
                if val.hasSuffix("]") { val = String(val.dropLast()) }
                dict[key] = val
            }
        }
        return dict
    }

    private func parseSmartSection(_ text: String, marker: String) -> [String: String] {
        guard let range = text.range(of: marker) else { return [:] }
        return parseKeyValues(String(text[range.lowerBound...]))
    }

    private func parseDataUnits(_ raw: String) -> Double {
        let parts = raw.components(separatedBy: "[").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 {
            let inner = parts[1]
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "TB", with: "")
                .replacingOccurrences(of: "GB", with: "")
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: ".")
            if let val = Double(inner) {
                return parts[1].contains("GB") ? val / 1000 : val
            }
        }
        if let first = parts.first, let val = Double(first) {
            return val * 512.0 / 1_000_000_000_000.0
        }
        return 0
    }

    private func formatBytes(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
            .replacingOccurrences(of: ",", with: ".")
        guard let bytes = Double(cleaned) else { return raw }
        let tb = bytes / 1_000_000_000_000
        if tb >= 1 { return String(format: "%.2f TB", tb) }
        let gb = bytes / 1_000_000_000
        return String(format: "%.1f GB", gb)
    }

    private func run(_ args: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let err = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw SmartCtlError.commandFailed(err)
        }

        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

enum SmartCtlError: LocalizedError {
    case commandFailed(String)
    var errorDescription: String? {
        switch self {
        case .commandFailed(let msg): return String(format: loc("smartctl_error"), msg)
        }
    }
}
