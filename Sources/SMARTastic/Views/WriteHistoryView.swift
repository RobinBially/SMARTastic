import SwiftUI
import Charts

struct WriteHistoryView: View {
    let disk: DiskInfo
    @Environment(AppModel.self) private var model
    @AppStorage("historyDays") private var range = 7
    @State private var selectedDate: Date?
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
                    ForEach([7, 30, 90], id: \.self) { Text(locf("history.days", $0)).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().frame(width: 210)
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
                }.frame(minHeight: 38)
                Chart {
                    ForEach(days) { day in
                        BarMark(x: .value(loc("history.day"), day.date, unit: .day), y: .value("GB", day.gb))
                            .foregroundStyle(LinearGradient(colors: day.date == today ? [.mint, .cyan] : [.cyan, .blue.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                            .opacity(selected == nil || selected?.date == day.date ? 1 : 0.35)
                            .cornerRadius(count == 90 ? 2 : 5)
                            .accessibilityLabel(day.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)))
                            .accessibilityValue(metric(day.gb, suffix: " GB", decimals: 2) + ", " + String(format: "%.1f h", day.seconds / 3600))
                        if day.gb == 0 {
                            PointMark(x: .value(loc("history.day"), day.date, unit: .day), y: .value("GB", 0))
                                .foregroundStyle(.cyan).symbolSize(15)
                        }
                    }
                    if let selected {
                        RuleMark(x: .value(loc("history.day"), selected.date, unit: .day)).foregroundStyle(.secondary.opacity(0.4))
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
                                selectedDate = date
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
                }.foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12))
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20).fill(Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [.cyan.opacity(0.07), .clear, .blue.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.cyan.opacity(0.13)))
        .onChange(of: range) { _, _ in selectedDate = nil }
        .onChange(of: disk.id) { _, _ in selectedDate = nil }
    }
}
