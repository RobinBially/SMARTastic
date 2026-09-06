import Foundation
import CryptoKit

/// Persist daily counter differences, never extrapolate a SMART lifetime average.
struct WriteHistory: Codable {
    struct Day: Codable, Identifiable {
        var date: Date
        var gb: Double = 0
        var seconds: Double = 0
        var estimated = false
        var id: Date { date }
    }
    struct Gap: Codable {
        let start: Date
        let end: Date
        let gb: Double
    }
    struct Drive: Codable {
        var timestamp: Date
        var writtenTB: Double
        var days: [Day] = []
        var gaps: [Gap] = []
    }
    var version = 1
    var timeZoneID = TimeZone.current.identifier
    var drives: [String: Drive] = [:]
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        return calendar
    }
    static func key(for disk: DiskInfo) -> String? {
        guard let serial = disk.serial?.trimmingCharacters(in: .whitespacesAndNewlines), !serial.isEmpty else { return nil }
        // Device paths can change or be reused. Do not persist raw serial numbers.
        return SHA256.hash(data: Data((disk.model + "\u{0}" + serial).utf8)).map { String(format: "%02x", $0) }.joined()
    }
    mutating func record(_ disk: DiskInfo, at now: Date) {
        guard disk.smartAvailable, let key = Self.key(for: disk),
              let total = disk.dataWrittenTB, total.isFinite, total >= 0 else { return }
        guard var drive = drives[key] else {
            drives[key] = Drive(timestamp: now, writtenTB: total)
            return
        }
        // Ignore stale/duplicate samples; a decreasing counter starts a new baseline.
        guard now > drive.timestamp else { return }
        let start = drive.timestamp
        let elapsed = now.timeIntervalSince(start)
        let gb = (total - drive.writtenTB) * 1000
        if gb >= 0 {
            if calendar.isDate(start, inSameDayAs: now) || elapsed <= 600 {
                var cursor = start
                while cursor < now {
                    let day = calendar.startOfDay(for: cursor)
                    let next = calendar.date(byAdding: .day, value: 1, to: day)!
                    let end = min(now, next)
                    let seconds = end.timeIntervalSince(cursor)
                    let index = drive.days.firstIndex { $0.date == day } ?? drive.days.count
                    if index == drive.days.count { drive.days.append(Day(date: day)) }
                    drive.days[index].gb += gb * seconds / elapsed
                    drive.days[index].seconds += seconds
                    drive.days[index].estimated = drive.days[index].estimated || !calendar.isDate(start, inSameDayAs: now)
                    cursor = end
                }
            } else {
                drive.gaps.append(Gap(start: start, end: now, gb: gb))
            }
        }
        drive.timestamp = now
        drive.writtenTB = total
        let cutoff = calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now))!
        drive.days.removeAll { $0.date < cutoff }
        drive.gaps.removeAll { $0.end < cutoff }
        drives[key] = drive
        drives = drives.filter { $0.value.timestamp >= cutoff }
    }
}

@MainActor @Observable
final class WriteHistoryStore {
    private(set) var history = WriteHistory()
    private(set) var failed = false
    private let url: URL?
    private var loadFailed = false

    init(url: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("SMARTastic/write-history.json")) {
        self.url = url
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            history = try JSONDecoder().decode(WriteHistory.self, from: Data(contentsOf: url))
            guard history.version == 1, TimeZone(identifier: history.timeZoneID) != nil else { throw CocoaError(.fileReadCorruptFile) }
        } catch { failed = true; loadFailed = true }
    }
    func record(_ disks: [DiskInfo], at now: Date) {
        guard !loadFailed else { return } // Preserve unreadable history for recovery.
        for disk in disks { history.record(disk, at: now) }
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(history).write(to: url, options: .atomic)
            failed = false
        } catch { failed = true }
    }
    func drive(for disk: DiskInfo) -> WriteHistory.Drive? {
        WriteHistory.key(for: disk).flatMap { history.drives[$0] }
    }
}
