import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var titlebarInset: CGFloat = 0
    @State private var search = ""
    @State private var exporting = false
    @State private var report: ReportDocument?
    @State private var exportError: String?

    private var filteredDisks: [DiskInfo] {
        model.disks.filter { search.isEmpty || $0.model.localizedCaseInsensitiveContains(search) || $0.interface.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    if let url = AppResources.bundle.url(forResource: "logo", withExtension: "png"), let image = NSImage(contentsOf: url) {
                        Image(nsImage: image).resizable().scaledToFit().frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SMARTastic").font(.system(size: 14, weight: .semibold))
                        Text(loc("sidebar.subtitle")).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(18)
                TextField(loc("search.placeholder"), text: $search)
                    .onExitCommand { search = "" }
                    .textFieldStyle(.roundedBorder).padding(.horizontal, 16).padding(.bottom, 12)
                List(selection: $model.selectedDiskID) {
                    Section(locf(model.disks.count == 1 ? "disk_count_one" : "disk_count_other", model.disks.count)) {
                        ForEach(filteredDisks) { disk in DiskCardView(disk: disk, isSelected: model.selectedDiskID == disk.id).tag(disk.id) }
                    }
                }.listStyle(.sidebar)
                if filteredDisks.isEmpty {
                    Text(loc(search.isEmpty ? "empty.no_drives" : "search.empty"))
                        .font(.system(size: 13)).foregroundStyle(.secondary).padding()
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc("appearance.title")).font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        AppearanceToggle()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc("refresh.interval"), systemImage: "arrow.clockwise")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Picker(loc("refresh.interval"), selection: $model.refreshInterval) {
                            Image(systemName: "pause.fill").tag(0.0)
                                .accessibilityLabel(loc("refresh.manual"))
                                .help(loc("refresh.pause.help"))
                            Text("30 s").tag(30.0).help(loc("refresh.30s"))
                            Text("1 min").tag(60.0).help(loc("refresh.1m"))
                            Text("5 min").tag(300.0).help(loc("refresh.5m"))
                        }
                        .pickerStyle(.segmented).labelsHidden()
                        .help(loc("refresh.segment.help"))
                        .disabled(model.isDemo)
                    }.padding(.vertical, 4)
                    if let last = model.lastRefreshed {
                        HStack {
                            Text(loc("refresh.updated"))
                            Text(last, style: .time)
                        }.font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }.padding(16)
            }.navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 360)
        } detail: {
            Group {
                if let disk = model.selectedDisk {
                    DiskDetailView(disk: disk, isDemo: model.isDemo, scanWarning: model.error)
                        .ignoresSafeArea(.container, edges: .top)
                } else {
                    VStack(spacing: 0) {
                        if let error = model.error { notice(error, icon: "exclamationmark.triangle", color: .orange) }
                        if model.isLoading {
                            ProgressView(loc("scan.loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ContentUnavailableView {
                                Label(loc(model.disks.isEmpty ? "empty.no_drives" : "detail.no_selection"), systemImage: "externaldrive")
                            } description: { Text(loc("empty.help")) } actions: {
                                Button(loc("button.scan")) { model.refresh() }.disabled(model.isDemo)
                            }
                        }
                    }
                }
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .background(WindowChrome())
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { titlebarInset = $0 }
        .overlay(alignment: .topTrailing) {
            windowActions.padding(.trailing, 24).padding(.top, 24).offset(y: -titlebarInset)
        }
        .fileExporter(isPresented: $exporting, document: report, contentType: .json, defaultFilename: "SMARTastic-report") { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert(loc("report.failed"), isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: { Text(exportError ?? "") }
        .onAppear { if model.lastRefreshed == nil { model.refresh() }; model.startAutoRefresh() }
        .onDisappear { model.stopAutoRefresh() }
    }
    private var windowActions: some View {
        HStack(spacing: 8) {
            if model.isLoading { ProgressView().controlSize(.small) }
            Button {
                do { report = try ReportDocument(disks: model.disks, sampledAt: model.lastRefreshed, demo: model.isDemo, warning: model.error); exporting = true }
                catch { exportError = error.localizedDescription }
            } label: { Label(loc("report.export"), systemImage: "square.and.arrow.up") }
            .disabled(model.disks.isEmpty || model.isLoading)
            .modifier(NativeCircleAction())
            .modifier(ActionTooltip(text: loc("report.help")))
            Button { model.refresh() } label: { Label(loc("button.refresh.help"), systemImage: "arrow.clockwise") }
                .disabled(model.isLoading || model.isDemo)
                .modifier(NativeCircleAction())
                .modifier(ActionTooltip(text: loc("refresh.now.help")))
        }
    }
    private func notice(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon).font(.system(size: 13)).foregroundStyle(color)
            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).background(color.opacity(0.08))
    }
}

struct ReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(disks: [DiskInfo], sampledAt: Date?, demo: Bool, warning: String?) throws {
        struct Report: Encodable {
            let schemaVersion = 1
            let sampledAt: Date?
            let demo: Bool
            let warning: String?
            let disks: [DiskInfo]
        }
        // Reports are intended for sharing. Serial numbers are omitted by default.
        let sanitized = disks.map { disk in var copy = disk; copy.serial = nil; return copy }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        data = try encoder.encode(Report(sampledAt: sampledAt, demo: demo, warning: warning, disks: sanitized))
    }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}


struct AppearanceToggle: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            option(.light, symbol: "sun.max.fill")
            option(.dark, symbol: "moon.stars.fill")
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
        .contextMenu {
            Button { model.appearance = .system } label: {
                Label(loc("appearance.system"), systemImage: "desktopcomputer")
            }
        }
    }
    private func option(_ appearance: AppAppearance, symbol: String) -> some View {
        let selected = appearance.colorScheme == colorScheme
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { model.appearance = appearance }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? (appearance == .light ? Color.orange : Color.cyan) : Color.secondary)
                .frame(width: 34, height: 26)
                .background {
                    if selected {
                        Capsule().fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                            .matchedGeometryEffect(id: "appearance-thumb", in: thumb)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(appearance.label + " · " + loc("appearance.help"))
        .accessibilityLabel(appearance.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}


private struct NativeCircleAction: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.labelStyle(.iconOnly).buttonStyle(.glass)
                .buttonBorderShape(.circle).controlSize(.large)
        } else {
            content.labelStyle(.iconOnly).buttonStyle(.bordered)
                .buttonBorderShape(.circle).controlSize(.large)
        }
    }
}

/// Let the scroll view occupy the full window behind the transparent toolbar.
private struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> ChromeView { ChromeView() }
    func updateNSView(_ view: ChromeView, context: Context) { view.configureWindow() }
    final class ChromeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindow()
        }
        func configureWindow() {
            guard let window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbarStyle = .unifiedCompact
            window.titlebarSeparatorStyle = .none
            window.toolbar?.showsBaselineSeparator = false
        }
    }
}
