import SwiftUI

struct DiskCardView: View {
    let disk: DiskInfo
    var isSelected = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: disk.icon).font(.title3).foregroundStyle(.secondary).frame(width: 25).padding(.top, 3)
            VStack(alignment: .leading, spacing: 6) {
                Text(disk.model).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                Text("\(disk.size) · \(disk.interface)").font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: disk.health.symbol)
                    Text(disk.healthLabel)
                    Spacer(minLength: 4)
                    Text(metric(disk.temperature, suffix: " °C")).monospacedDigit()
                }.font(.system(size: 12)).foregroundStyle(isSelected ? .white : disk.healthColor)
            }
        }.padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
