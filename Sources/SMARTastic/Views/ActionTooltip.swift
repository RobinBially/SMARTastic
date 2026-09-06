import SwiftUI

/// Titlebar overlays cannot rely on SwiftUI's delayed help bubble. Keep the
/// native button, and draw its explanation using AppKit pointer tracking.
struct ActionTooltip: ViewModifier {
    let text: String
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .accessibilityHint(text)
            .background {
                PointerTracking { hovered = $0 }
            }
            .overlay(alignment: .topTrailing) {
                if hovered {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(width: 260, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.1)))
                        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
                        .offset(y: 44)
                        .allowsHitTesting(false)
                }
            }
            .onDisappear { hovered = false }
    }
}

private struct PointerTracking: NSViewRepresentable {
    var onChange: (Bool) -> Void
    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }
    func updateNSView(_ view: TrackingView, context: Context) {
        view.onChange = onChange
    }
    final class TrackingView: NSView {
        var onChange: (Bool) -> Void = { _ in }
        private var area: NSTrackingArea?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area { removeTrackingArea(area) }
            let area = NSTrackingArea(rect: bounds,
                                      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                      owner: self, userInfo: nil)
            addTrackingArea(area)
            self.area = area
        }
        override func mouseEntered(with event: NSEvent) { onChange(true) }
        override func mouseExited(with event: NSEvent) { onChange(false) }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { onChange(false) }
        }
    }
}
