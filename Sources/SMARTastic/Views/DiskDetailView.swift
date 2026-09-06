import SwiftUI

struct DiskDetailView: View {
    let disk: DiskInfo
    var isDemo = false
    var scanWarning: String?
    @State private var detailWidth: CGFloat = 0
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: detailWidth >= 720 ? 4 : 2)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if isDemo {
                    Label(loc("demo.notice"), systemImage: "photo")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                if let scanWarning {
                    Label(scanWarning, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 13)).foregroundStyle(.orange).textSelection(.enabled)
                }
                header
                status
                if disk.smartAvailable {
                    section(loc("section.health")) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: disk.driveType == .ssd && detailWidth >= 720 ? 4 : 2), spacing: 12) {
                            healthMetrics
                        }
                    }
                    section(loc("section.usage")) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            MetricTile(label: loc("metric.written"), value: metric(disk.dataWrittenTB, suffix: " TB", decimals: 2), icon: "arrow.down.to.line", color: .cyan)
                            MetricTile(label: loc("metric.read"), value: metric(disk.dataReadTB, suffix: " TB", decimals: 2), icon: "arrow.up.to.line", color: .cyan)
                            MetricTile(label: loc("metric.power_on_time"), value: metric(disk.powerOnHours), icon: "clock", detail: loc("metric.power_on_detail"))
                                .help(loc("power_on.help"))
                            MetricTile(label: loc("metric.power_cycles"), value: metric(disk.powerCycles), icon: "power")
                        }
                    }
                    WriteHistoryView(disk: disk)
                    if disk.percentageUsed != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(loc("endurance.title"), systemImage: "info.circle").font(.subheadline.weight(.medium))
                            Text(loc("endurance.explanation")).font(.system(size: 13)).foregroundStyle(.secondary)
                            if let volume = disk.writtenGBPer24PowerOnHours {
                                Text(loc("detail.written_per_smart_day") + ": " + metric(volume, suffix: " GB", decimals: 1))
                                    .font(.system(size: 13))
                                    .help(loc("detail.written_per_smart_day.help"))
                            }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                section(loc("section.drive_info")) {
                    VStack(spacing: 0) {
                        InfoRow(label: loc("info.serial"), value: disk.serial ?? "—")
                        Divider()
                        InfoRow(label: loc("info.firmware"), value: disk.firmware ?? "—")
                        Divider()
                        InfoRow(label: loc("info.capacity"), value: disk.size)
                        Divider()
                        InfoRow(label: loc("metric.unsafe_shutdowns"), value: metric(disk.unsafeShutdowns))
                    }.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
                }
                if let diagnostic = disk.diagnostic {
                    DisclosureGroup(loc("diagnostics.title")) {
                        Text(diagnostic).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    }.disclosureGroupStyle(FullRowDisclosureStyle())
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Text(loc("data.disclaimer")).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailWidth = $0 }
            .padding(26).padding(.top, 22).frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
        }
    }
    @ViewBuilder private var healthMetrics: some View {
        MetricTile(label: loc("gauge.temperature"), value: metric(disk.temperature, suffix: " °C"), icon: "thermometer.medium", color: disk.tempColor)
        MetricTile(label: loc("gauge.media_errors"), value: metric(disk.mediaErrors), icon: "exclamationmark.circle", color: (disk.mediaErrors ?? 0) > 0 ? .orange : .secondary)
        if disk.driveType == .ssd {
            MetricTile(label: loc("endurance.remaining"), value: metric(disk.remainingEndurance, suffix: " %"), icon: "chart.bar", color: disk.healthColor, progress: disk.remainingEndurance)
            MetricTile(label: loc("gauge.spare"), value: metric(disk.availableSpare, suffix: " %"), icon: "square.stack.3d.up", color: .teal, progress: disk.availableSpare)
        }
    }
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: disk.icon).font(.system(size: 28)).foregroundStyle(.cyan)
                .frame(width: 58, height: 58).background(.cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 6) {
                Text(disk.model).font(.system(size: 21, weight: .semibold)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Text("\(disk.size)  ·  \(disk.driveType.rawValue)  ·  \(disk.interface)").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
    private var status: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: disk.health.symbol).font(.title2).foregroundStyle(disk.healthColor)
            VStack(alignment: .leading, spacing: 5) {
                Text(disk.healthLabel).font(.system(size: 14, weight: .semibold))
                Text(loc(!disk.smartAvailable ? "nosmart.message" : disk.health == .critical ? "status.critical" : disk.health == .warning ? "status.warning" : disk.health == .healthy ? "status.healthy" : "status.unknown"))
                    .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(disk.healthColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 15, weight: .semibold))
            content()
        }
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = .secondary
    var detail: String = ""
    var progress: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) { Image(systemName: icon).foregroundStyle(color); Text(label).foregroundStyle(Color.secondary) }.font(.system(size: 13))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.system(size: 23, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                if !detail.isEmpty { Text(detail).font(.system(size: 12)).foregroundStyle(.secondary) }
            }
            if let progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.15))
                        Capsule().fill(color).frame(width: geometry.size.width * max(0, min(100, progress)) / 100)
                    }
                }.frame(height: 5).accessibilityHidden(true)
            }
        }.frame(minWidth: 130, maxWidth: .infinity, minHeight: 84, alignment: .leading).padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.05), lineWidth: 1))
            .accessibilityElement(children: .combine)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).monospacedDigit().textSelection(.enabled).multilineTextAlignment(.trailing)
        }.font(.system(size: 13)).padding(.horizontal, 16).padding(.vertical, 11)
    }
}
