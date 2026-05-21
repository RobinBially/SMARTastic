import SwiftUI

struct DiskCardView: View {
    let disk: DiskInfo
    var isSelected: Bool = false
    @State private var hovering = false

    private var borderColor: Color {
        if isSelected { return disk.healthColor.opacity(0.6) }
        if hovering { return Color.primary.opacity(0.15) }
        return Color.gray.opacity(0.25)
    }

    var body: some View {
        HStack(spacing: 12) {
            icon
            info
            Spacer(minLength: 8)
            indicators
        }
        .padding(12)
        .background(background)
        .onHover { hovering = $0 }
        .scaleEffect(hovering ? 1.015 : 1)
        .animation(.interpolatingSpring(duration: 0.25), value: hovering)
    }

    // MARK: - Icon

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(disk.healthColor.gradient)
                .frame(width: 40, height: 40)
                .shadow(color: disk.healthColor.opacity(0.3), radius: 4, y: 2)
            Image(systemName: disk.icon)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Info

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(disk.model)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)

            HStack(spacing: 4) {
                Text(disk.size)
                Text(disk.interface).foregroundStyle(.tertiary)
                if disk.smartAvailable {
                    Text("\u{2022}").foregroundStyle(.tertiary)
                    Text(disk.driveType.rawValue).foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if disk.smartAvailable {
                HStack(spacing: 4) {
                    Circle().fill(disk.healthColor).frame(width: 6, height: 6)
                    Text(disk.healthLabel)
                        .font(.caption2)
                        .foregroundStyle(disk.healthColor)
                        .fixedSize()
                    if disk.driveType == .ssd {
                        Text("\u{2022}").foregroundStyle(.tertiary).font(.caption2)
                        Text("\(Int(disk.percentageUsed))%").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle").font(.caption2)
                    Text("SMART n/v").font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Indicators

    @ViewBuilder
    private var indicators: some View {
        if disk.smartAvailable {
            HStack(spacing: 6) {
                if disk.driveType == .ssd {
                    ring(value: disk.percentageUsed, maxValue: 100, inverted: true,
                         color: disk.healthColor, label: "%")
                }
                ring(value: disk.temperature, maxValue: disk.driveType == .ssd ? 85 : 65,
                     inverted: false, color: disk.tempColor, label: "\u{00B0}")
            }
        }
    }

    private func ring(value: Double, maxValue: Double, inverted: Bool, color: Color, label: String) -> some View {
        let p = Swift.max(0, min(1, inverted ? 1 - (value / maxValue) : value / maxValue))
        let display = Int(inverted ? Swift.max(0, maxValue - value) : value)
        return ZStack {
            Circle().stroke(.quaternary.opacity(0.4), lineWidth: 4)
            Circle().trim(from: 0, to: p)
                .stroke(AngularGradient(colors: [color.opacity(0.4), color], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.5), value: p)
            VStack(spacing: 0) {
                Text("\(display)").font(.system(size: 10, weight: .bold)).monospacedDigit()
                Text(label).font(.system(size: 6, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
    }

    // MARK: - Background

    private var background: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 0.5)
            }
            .shadow(color: isSelected ? disk.healthColor.opacity(0.15) :
                    hovering ? .black.opacity(0.08) : .clear,
                    radius: 8, y: 3)
    }
}
