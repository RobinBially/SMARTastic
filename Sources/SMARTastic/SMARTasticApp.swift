import SwiftUI

@main
struct SMARTasticApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("SMARTastic", id: "main") {
            ContentView()
                .environment(model)
                .onAppear { NSApplication.shared.appearance = model.appearance.nsAppearance }
                .onChange(of: model.appearance) { _, appearance in
                    NSApplication.shared.appearance = appearance.nsAppearance
                }
                .frame(minWidth: 940, minHeight: 660)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 790)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button(loc("button.refresh.help")) { model.refresh() }
                    .keyboardShortcut("r")
                    .disabled(model.isLoading || model.isDemo)
            }
        }
    }
}

enum AppAppearance: String, CaseIterable {
    case system, light, dark
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
    var label: String { loc("appearance." + rawValue) }
}

@MainActor @Observable
final class AppModel {
    var disks: [DiskInfo] = []
    var isLoading = false
    var error: String?
    var selectedDiskID: DiskInfo.ID?
    var lastRefreshed: Date?
    let isDemo: Bool
    var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }
    var refreshInterval: Double {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            startAutoRefresh()
        }
    }
    private var timer: Timer?
    private let scanner: @Sendable () async throws -> ScanResult

    init(isDemo: Bool = ProcessInfo.processInfo.arguments.contains("--demo"),
         scanner: @escaping @Sendable () async throws -> ScanResult = { try await SmartCtlService.shared.scan() }) {
        self.isDemo = isDemo
        self.scanner = scanner
        let savedAppearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "system") ?? .system
        appearance = isDemo && ProcessInfo.processInfo.arguments.contains("--light") ? .light : savedAppearance
        let saved = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 60
        refreshInterval = [0, 30, 60, 300].contains(saved) ? saved : 60
        if isDemo {
            disks = DemoData.disks
            selectedDiskID = disks.first?.id
            lastRefreshed = .now
        }
    }
    var selectedDisk: DiskInfo? { disks.first { $0.id == selectedDiskID } }

    func startAutoRefresh() {
        stopAutoRefresh()
        guard refreshInterval > 0, !isDemo else { return }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func stopAutoRefresh() { timer?.invalidate(); timer = nil }

    func refresh() {
        guard !isLoading, !isDemo else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let result = try await scanner()
                disks = result.disks
                error = result.warning
                lastRefreshed = .now
                if !disks.contains(where: { $0.id == selectedDiskID }) { selectedDiskID = disks.first?.id }
            } catch { self.error = error.localizedDescription }
        }
    }
}
