import SwiftUI

struct DiskDetailView: View {
    let disk: DiskInfo

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                if disk.smartAvailable {
                    healthOverview
                    performanceSection
                    attributesSection
                } else {
                    noSmartSection
                }
                infoSection
            }
            .padding(24)
        }
        .background()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(disk.healthColor.gradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: disk.healthColor.opacity(0.35), radius: 8, y: 4)
                Image(systemName: disk.icon)
                    .font(.title.weight(.medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(disk.model)
                    .font(.title2.weight(.semibold))
                HStack(spacing: 8) {
                    Badge(disk.driveType.rawValue, color: .blue)
                    Badge(disk.interface, color: .secondary)
                    if disk.smartAvailable {
                        Badge(loc(disk.smartPassed ? "badge.smart_ok" : "badge.smart_error"),
                              color: disk.smartPassed ? .green : .red)
                        Badge(disk.healthLabel, color: disk.healthColor)
                    } else {
                        Badge(loc("badge.smart_na"), color: .gray)
                    }
                }
            }

            Spacer()

            if disk.smartAvailable {
                healthScoreBadge
            }
        }
    }

    private var healthScoreBadge: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: Double(disk.healthScore) / 100)
                    .stroke(
                        AngularGradient(colors: [disk.healthColor.opacity(0.4), disk.healthColor],
                                       center: .center),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                    .animation(.smooth, value: disk.healthScore)
                Text("\(disk.healthScore)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
            Text(LocalizedStringKey("label.health"), bundle: .module)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Health Overview

    private var healthOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(loc("section.health"), icon: "heart.text.clipboard")

            HStack(spacing: 20) {
                if disk.driveType == .ssd {
                    LargeGauge(
                        value: disk.percentageUsed,
                        maxValue: 100,
                        label: loc("gauge.lifespan"),
                        unit: loc("gauge.lifespan_unit"),
                        inverted: true,
                        color: disk.healthColor,
                        detail: disk.remainingLifeEstimate
                    )
                }

                LargeGauge(
                    value: disk.temperature,
                    maxValue: disk.driveType == .ssd ? 85 : 65,
                    label: loc("gauge.temperature"),
                    unit: "\u{00B0}C",
                    inverted: false,
                    color: disk.tempColor,
                    detail: disk.tempLabel
                )

                LargeGauge(
                    value: disk.availableSpare,
                    maxValue: 100,
                    label: loc("gauge.spare"),
                    unit: "%",
                    inverted: false,
                    color: .green,
                    detail: loc("gauge.spare_detail")
                )

                LargeGauge(
                    value: Double(disk.mediaErrors),
                    maxValue: max(100, Double(disk.mediaErrors) * 2),
                    label: loc("gauge.media_errors"),
                    unit: "",
                    inverted: false,
                    color: disk.mediaErrors == 0 ? .green : .red,
                    detail: disk.mediaErrors == 0 ? loc("gauge.media_errors_detail_none") : "\(disk.mediaErrors)"
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    // MARK: - Performance

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(loc("section.usage"), icon: "chart.bar.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if disk.driveType == .ssd {
                    MetricBox(icon: "arrow.down.circle", label: loc("metric.read"),
                              value: "\(String(format: "%.1f", disk.dataReadTB)) TB",
                              detail: "\(String(format: "%.1f", disk.dailyReadGB)) \(loc("metric.per_day"))")
                    MetricBox(icon: "arrow.up.circle", label: loc("metric.written"),
                              value: "\(String(format: "%.1f", disk.dataWrittenTB)) TB",
                              detail: "\(String(format: "%.1f", disk.dailyWriteGB)) \(loc("metric.per_day"))")
                } else {
                    MetricBox(icon: "arrow.down.circle", label: loc("metric.read"), value: "\u{2014}", detail: "")
                    MetricBox(icon: "arrow.up.circle", label: loc("metric.written"), value: "\u{2014}", detail: "")
                }
                MetricBox(icon: "clock", label: loc("metric.power_on_time"),
                          value: disk.powerOnFormatted,
                          detail: "\(disk.powerOnHours) \(loc("metric.power_on_detail"))")
                MetricBox(icon: "power", label: loc("metric.power_cycles"),
                          value: "\(disk.powerCycles)",
                          detail: loc("metric.power_cycles_detail"))
                if disk.driveType == .ssd {
                    MetricBox(icon: "exclamationmark.triangle", label: loc("metric.unsafe_shutdowns"),
                              value: "\(disk.unsafeShutdowns)",
                              detail: loc("metric.unsafe_shutdowns_detail"))
                }
                MetricBox(icon: "ant", label: loc("gauge.media_errors"),
                          value: "\(disk.mediaErrors)",
                          detail: disk.mediaErrors == 0 ? loc("metric.media_errors_none") : loc("metric.media_errors_some"))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    // MARK: - Attributes (table for ATA, key metrics for NVMe)

    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(loc("section.life_prognosis"), icon: "calendar")

            HStack(spacing: 16) {
                if disk.driveType == .ssd {
                    DetailBox(label: loc("detail.life_consumed"),
                              value: "\(String(format: "%.1f", disk.percentageUsed))%",
                              icon: "timer")
                    DetailBox(label: loc("detail.avg_write_rate"),
                              value: "\(String(format: "%.1f", disk.dailyWriteGB)) \(loc("metric.per_day"))",
                              icon: "speedometer")
                    DetailBox(label: loc("detail.remaining_life"),
                              value: disk.remainingLifeEstimate,
                              icon: "hourglass")
                } else {
                    DetailBox(label: loc("detail.power_on"),
                              value: disk.powerOnFormatted,
                              icon: "clock")
                    DetailBox(label: loc("detail.power_cycles"),
                              value: "\(disk.powerCycles)",
                              icon: "power")
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    // MARK: - No SMART

    private var noSmartSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("nosmart.title"), bundle: .module)
                        .font(.headline)
                    Text(LocalizedStringKey("nosmart.message"), bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        }
    }

    // MARK: - Drive Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(loc("section.drive_info"), icon: "info.circle.fill")

            VStack(spacing: 0) {
                InfoRow(label: loc("info.serial"), value: disk.serial)
                Divider().padding(.leading, 120)
                InfoRow(label: loc("info.firmware"), value: disk.firmware)
                Divider().padding(.leading, 120)
                InfoRow(label: loc("info.capacity"), value: disk.size)
                Divider().padding(.leading, 120)
                InfoRow(label: loc("info.interface"), value: disk.interface)
                if disk.driveType == .ssd {
                    Divider().padding(.leading, 120)
                    InfoRow(label: loc("info.tbw"),
                            value: disk.percentageUsed > 0
                                ? "\(String(format: "%.0f", disk.dataWrittenTB / disk.percentageUsed * 100)) TB"
                                : "\u{2014}")
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
    }
}

// MARK: - Large Gauge

struct LargeGauge: View {
    let value: Double
    let maxValue: Double
    let label: String
    let unit: String
    let inverted: Bool
    let color: Color
    let detail: String

    private var progress: Double {
        let p = value / maxValue
        return max(0, min(1, inverted ? 1 - p : p))
    }

    private var displayValue: Int {
        Int(inverted ? max(0, maxValue - value) : value)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary.opacity(0.4), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [color.opacity(0.3), color], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.6), value: progress)

                VStack(spacing: 0) {
                    Text("\(displayValue)")
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 90, height: 90)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subviews

struct Badge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.85))
            .clipShape(Capsule())
    }
}

struct MetricBox: View {
    let icon: String
    let label: String
    let value: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
    }
}

struct DetailBox: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
