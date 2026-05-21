import SwiftUI

@main
struct SMARTasticApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("SMARTastic", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

@Observable
final class AppModel {
    var disks: [DiskInfo] = []
    var isLoading = false
    var error: String?
    var selectedDiskID: DiskInfo.ID?
    var lastRefreshed: Date?

    private var timer: Timer?

    nonisolated init() {}

    var selectedDisk: DiskInfo? {
        disks.first { $0.id == selectedDiskID }
    }

    func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        Task {
            do {
                let result = try await SmartCtlService.shared.scan()
                await MainActor.run {
                    disks = result
                    lastRefreshed = .now
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
