import SwiftUI
import Charts

struct WriteHistoryView: View {
    let disk: DiskInfo
    @Environment(AppModel.self) private var model
    @AppStorage("historyDays") private var range = 7
    @State private var selectedDate: Date?
    @State private var hoveredDate: Date?
    @State private var hoverPoint: CGPoint = .zero
    @State private var showingDetails = false
    private var calendar: Calendar { model.writeHistory.history.calendar }
    private var count: Int { [7, 30, 90].contains(range) ? range : 7 }
    private var today: Date { calendar.startOfDay(for: model.lastRefreshed ?? .now) }
    private var start: Date { calendar.date(byAdding: .day, value: 1 - count, to: today)! }
    private var end: Date { calendar.date(byAdding: .day, value: 1, to: today)! }
    private var drive: WriteHistory.Drive? { model.writeHistory.drive(for: disk) }
    private var days: [WriteHistory.Day] { drive?.days.filter { $0.date >= start && $0.date < end } ?? [] }
    private var selected: WriteHistory.Day? {
        guard let selectedDate else { return nil }
        return days.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    private var highlighted: WriteHistory.Day? {
        guard let date = hoveredDate ?? selectedDate else { return nil }
        return days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    private var gapsGB: Double {
        drive?.gaps.filter { $0.end >= start && $0.start < end }.reduce(0) { $0 + $1.gb } ?? 0
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 36, height: 36)
                    .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                Text(loc("history.title")).font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker(loc("history.range"), selection: $range) {
                    ForEach([7, 30, 90], id: \.self) { Text(locf("history.days", $0)).tag($0).help(locf("history.range.help", $0)) }
                }.pickerStyle(.segmented).labelsHidden().frame(width: 210)
                    .help(loc("history.range.general"))
            }
            if model.writeHistory.failed {
                Label(loc("history.error"), systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            if WriteHistory.key(for: disk) == nil || disk.dataWrittenTB == nil {
                Text(loc("history.unavailable")).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(metric(selected?.gb ?? (days.isEmpty ? nil : days.reduce(0) { $0 + $1.gb }), suffix: " GB", decimals: 2))
                        .font(.system(size: 23, weight: .semibold)).monospacedDigit()
                    Text(selected.map { $0.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)) } ?? loc("history.recorded"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if selected == nil {
                        VStack(alignment: .trailing, spacing: 4) {
                            Label(loc("history.today"), systemImage: "sun.max")
                                .foregroundStyle(.secondary)
                            Text(metric(days.first { $0.date == today }?.gb, suffix: " GB", decimals: 2))
                                .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                        }
                    }
                    if let selected {
                        Text(String(format: "%.1f h", selected.seconds / 3600)).foregroundStyle(.secondary)
                    }
                }.frame(height: 44)
                Chart {
                    ForEach(days) { day in
                        BarMark(x: .value(loc("history.day"), day.date, unit: .day), y: .value("GB", day.gb))
                            .foregroundStyle(LinearGradient(colors: day.date == today ? [.mint, .cyan] : [.cyan, .blue.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                            .opacity(highlighted == nil || highlighted?.date == day.date ? 1 : 0.35)
                            .cornerRadius(count == 90 ? 2 : 5)
                            .accessibilityLabel(day.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)))
                            .accessibilityValue(metric(day.gb, suffix: " GB", decimals: 2) + ", " + String(format: "%.1f h", day.seconds / 3600))
                        if day.gb == 0 {
                            PointMark(x: .value(loc("history.day"), day.date, unit: .day), y: .value("GB", 0))
                                .foregroundStyle(.cyan).symbolSize(15)
                        }
                    }
                    if let highlighted {
                        RuleMark(x: .value(loc("history.day"), highlighted.date, unit: .day)).foregroundStyle(.secondary.opacity(0.4))
                    }
                }
                .chartXScale(domain: start...end)
                .chartYScale(domain: 0...max(1, (days.map(\.gb).max() ?? 0) * 1.15))
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: count == 7 ? 1 : count == 30 ? 5 : 15)) { _ in
                    AxisGridLine(); AxisValueLabel(format: .dateTime.day().month())
                } }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartYAxisLabel("GB")
                .chartXSelection(value: $selectedDate)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let frame = proxy.plotFrame else { return }
                                let plot = geometry[frame]
                                guard plot.contains(location) else { selectedDate = nil; return }
                                let date: Date? = proxy.value(atX: location.x - plot.minX)
                                if let date, let selectedDate, calendar.isDate(date, inSameDayAs: selectedDate) {
                                    self.selectedDate = nil
                                } else { selectedDate = date }
                            }
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let frame = proxy.plotFrame, geometry[frame].contains(location) else {
                                        hoveredDate = nil; return
                                    }
                                    hoverPoint = location
                                    hoveredDate = proxy.value(atX: location.x - geometry[frame].minX)
                                case .ended: hoveredDate = nil
                                }
                            }
                        if let date = hoveredDate ?? selectedDate, let frame = proxy.plotFrame {
                            let plot = geometry[frame]
                            let dayStart = calendar.startOfDay(for: date)
                            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                            let middle = dayStart.addingTimeInterval(nextDay.timeIntervalSince(dayStart) / 2)
                            let anchor = hoveredDate != nil ? hoverPoint.x : (proxy.position(forX: middle) ?? 0) + plot.minX
                            hoverCard(for: date)
                                .frame(width: 210)
                                .fixedSize(horizontal: false, vertical: true)
                                .position(x: min(max(anchor, plot.minX + 109), plot.maxX - 109), y: plot.minY + 48)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .environment(\.calendar, calendar)
                .environment(\.timeZone, calendar.timeZone)
                .frame(height: 185)
                .overlay {
                    if days.isEmpty {
                        Text(loc("history.empty")).multilineTextAlignment(.center).foregroundStyle(.secondary)
                            .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)).padding(28)
                    }
                }
                if gapsGB > 0 {
                    Label(locf("history.gaps", gapsGB), systemImage: "calendar.badge.exclamationmark").foregroundStyle(.orange)
                }
                HStack {
                    Label(locf("history.observed", days.count, count), systemImage: "clock.badge.checkmark")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if model.isDemo {
                        Text(loc("history.demo")).foregroundStyle(.cyan)
                    }
                }
                DisclosureGroup(loc("history.details"), isExpanded: $showingDetails) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(loc("history.note"))
                        Text(locf("history.timezone", calendar.timeZone.identifier))
                    }.foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                }.disclosureGroupStyle(FullRowDisclosureStyle())
                    .foregroundStyle(.secondary)
                    .help(loc("history.details.help"))
            }
        }
        .font(.system(size: 12))
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20).fill(Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [.cyan.opacity(0.07), .clear, .blue.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.cyan.opacity(0.13)))
        .onChange(of: range) { _, _ in selectedDate = nil; hoveredDate = nil }
        .onChange(of: disk.id) { _, _ in selectedDate = nil; hoveredDate = nil }
    }
    private func hoverCard(for date: Date) -> some View {
        let day = days.first { calendar.isDate($0.date, inSameDayAs: date) }
        return VStack(alignment: .leading, spacing: 5) {
            Text(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)))
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            if let day {
                HStack(alignment: .firstTextBaseline) {
                    Text(metric(day.gb, suffix: " GB", decimals: 2))
                        .font(.system(size: 19, weight: .semibold)).monospacedDigit()
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.down.to.line").foregroundStyle(.cyan)
                }
                Text(locf("history.hours", day.seconds / 3600)).foregroundStyle(.secondary)
                if day.estimated { Text(loc("history.estimated")).foregroundStyle(.secondary) }
            } else {
                Text(loc("history.no_measurement")).font(.system(size: 13, weight: .medium))
            }
        }
        .font(.system(size: 11))
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }
}
