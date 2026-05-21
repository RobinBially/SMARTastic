import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 380, ideal: 400, max: 460)
        } detail: {
            detail
        }
        .onAppear {
            if model.disks.isEmpty {
                model.refresh()
            }
            model.startAutoRefresh()
        }
        .onDisappear {
            model.stopAutoRefresh()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = model.error {
                errorView(error)
            } else if model.disks.isEmpty && !model.isLoading {
                emptyView
            } else {
                list
            }
            Divider()
            footer
        }
        .background()
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.blue.gradient)
                    .frame(width: 34, height: 34)
                Image(systemName: "internaldrive")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("SMARTastic")
                    .font(.headline.weight(.semibold))
                Text(LocalizedStringKey("sidebar.subtitle"), bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            }

            Button { model.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .disabled(model.isLoading)
            .help(loc("button.refresh.help"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(model.disks) { disk in
                    DiskCardView(disk: disk, isSelected: model.selectedDiskID == disk.id)
                        .onTapGesture {
                            model.selectedDiskID = disk.id
                        }
                        .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(LocalizedStringKey("empty.no_drives"), bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(loc("button.scan")) { model.refresh() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(msg)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(loc("button.retry")) { model.refresh() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if !model.disks.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text(verbatim: locf(model.disks.count == 1 ? "disk_count_one" : "disk_count_other", model.disks.count))
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                if let last = model.lastRefreshed {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(verbatim: locf("time.ago", relative(last)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let last = model.lastRefreshed {
                Text(last, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: .now)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let disk = model.selectedDisk {
            DiskDetailView(disk: disk)
        } else {
            noSelection
        }
    }

    private var noSelection: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(LocalizedStringKey("detail.no_selection"), bundle: .module)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background()
    }
}
