import Foundation
import Darwin

struct ScanResult {
    var disks: [DiskInfo]
    var warning: String?
}

actor SmartCtlService {
    static let shared = SmartCtlService()

    func scan() throws -> ScanResult {
        let smartctl = ["/opt/homebrew/bin/smartctl", "/usr/local/bin/smartctl", "/usr/bin/smartctl"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
        let listing = try CommandRunner.run("/usr/sbin/diskutil", ["list", "-plist", "physical"])
        guard listing.status == 0,
              let plist = try PropertyListSerialization.propertyList(from: listing.data, format: nil) as? [String: Any],
              let devices = plist["WholeDisks"] as? [String] else {
            throw SmartCtlError.commandFailed(loc("error.discovery"))
        }
        var disks: [DiskInfo] = []
        var warnings: [String] = []
        if smartctl == nil { warnings.append(loc("error.install")) }
        for identifier in devices {
            let device = "/dev/" + identifier
            do {
                let result = try CommandRunner.run("/usr/sbin/diskutil", ["info", "-plist", device])
                guard result.status == 0,
                      let info = try PropertyListSerialization.propertyList(from: result.data, format: nil) as? [String: Any] else {
                    throw SmartCtlError.commandFailed(loc("error.discovery"))
                }
                var disk = DiskInfo(id: device, model: info["MediaName"] as? String ?? identifier,
                                    serial: info["SerialNumber"] as? String,
                                    capacityBytes: SmartParser.number(info["TotalSize"]),
                                    driveType: (info["SolidState"] as? Bool).map { $0 ? .ssd : .hdd } ?? .unknown,
                                    interface: info["BusProtocol"] as? String ?? "—")
                if let smartctl {
                    do {
                        // Identity, health and attributes include all displayed counters.
                        // -a additionally requests optional logs that Apple NVMe can reject.
                        let output = try CommandRunner.run(smartctl, ["-i", "-H", "-A", "-j", device])
                        // smartctl uses a bitmask: nonzero often means valid data with health/read warnings.
                        disk = try SmartParser.parse(output.data, device: device, fallback: disk)
                        if output.status != 0 && disk.diagnostic == nil {
                            disk.diagnostic = locf("error.exit_status", output.status)
                        }
                    } catch { disk.diagnostic = error.localizedDescription }
                } else { disk.diagnostic = loc("error.install") }
                disks.append(disk)
            } catch { warnings.append("\(identifier): \(error.localizedDescription)") }
        }
        return ScanResult(disks: disks.sorted { $0.model.localizedStandardCompare($1.model) == .orderedAscending },
                          warning: warnings.isEmpty ? nil : warnings.joined(separator: "\n"))
    }
}

struct CommandOutput { let data: Data; let status: Int32 }

enum CommandRunner {
    /// File-backed output prevents pipe-buffer deadlocks; each command has a hard deadline.
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 12) throws -> CommandOutput {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("output")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let handle = try FileHandle(forWritingTo: outputURL)
        defer { try? handle.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = handle
        // smartctl supplies diagnostics in JSON; diskutil failures get an actionable app error.
        process.standardError = FileHandle.nullDevice
        try process.run()
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline { Thread.sleep(forTimeInterval: 0.02) }
        if process.isRunning {
            process.terminate()
            let grace = ProcessInfo.processInfo.systemUptime + 0.25
            while process.isRunning && ProcessInfo.processInfo.systemUptime < grace { Thread.sleep(forTimeInterval: 0.01) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            throw SmartCtlError.commandFailed(locf("error.timeout", URL(fileURLWithPath: executable).lastPathComponent))
        }
        process.waitUntilExit()
        return CommandOutput(data: try Data(contentsOf: outputURL), status: process.terminationStatus)
    }
}

enum SmartCtlError: LocalizedError {
    case commandFailed(String)
    var errorDescription: String? { if case .commandFailed(let message) = self { return message }; return nil }
}
