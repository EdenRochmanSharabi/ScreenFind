import SwiftUI
import AppKit

/// NSVisualEffectView wrapper. SwiftUI materials (.ultraThinMaterial etc.) don't
/// reliably render on transparent non-activating panels, so use AppKit's
/// behind-window blur directly — same approach as Spotlight-like apps.
/// `.popover` is a thicker, light/dark-adaptive material: per the HIG, thicker
/// materials give text the contrast it needs (`.hudWindow` is reserved for
/// dark HUDs in media apps).
struct VisualEffectBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        print("[SearchBarView] VisualEffectBackground.makeNSView")
        let view = NSVisualEffectView()
        // .menu is the lighter translucent gray Spotlight uses; .popover
        // reads too dark next to it.
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        // Shape the backdrop blur itself: SwiftUI's clipShape only masks the
        // view layer, and the window-server blur region can bleed past it,
        // leaving corners visibly uneven.
        view.maskImage = .roundedCornerMask(radius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private extension NSImage {
    /// A stretchable rounded-rect mask (standard capInsets trick) used to
    /// shape an NSVisualEffectView's backdrop blur.
    static func roundedCornerMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

struct SearchBarContentView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var isFocused: Bool

    static let panelSize = CGSize(width: 480, height: 64)
    static let cornerRadius: CGFloat = 18

    /// Transparent margin around the pill inside the window. The window's own
    /// (titled) corner rounding clips at the window edge; keeping the pill
    /// away from the edges leaves all four corners identical.
    static let windowMargin: CGFloat = 16

    /// The full window size: pill + transparent margin.
    static var windowSize: CGSize {
        CGSize(width: panelSize.width + windowMargin * 2, height: panelSize.height + windowMargin * 2)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.primary.opacity(0.85))

            TextField(
                "",
                text: $viewModel.query,
                prompt: Text("Search screen…").foregroundColor(.secondary)
            )
            .textFieldStyle(.plain)
            .focused($isFocused)
            .font(.system(size: 24, weight: .medium))

            if !viewModel.query.isEmpty {
                Button(action: { viewModel.query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

            if !viewModel.isOCRComplete {
                ProgressView()
                    .controlSize(.small)
            }

            if !viewModel.query.isEmpty && viewModel.isOCRComplete {
                Text("\(viewModel.totalMatches > 0 ? "\(viewModel.currentMatchIndex + 1)" : "0")/\(viewModel.totalMatches)")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                    .monospacedDigit()

                Button(action: viewModel.navigateToPrevious) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)

                Button(action: viewModel.navigateToNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 20)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .background(
            // Blur + a strong base tint: the material alone takes the color of
            // whatever is behind the panel (a dark terminal → black pill).
            // Spotlight keeps its light/dark gray regardless of the backdrop.
            ZStack {
                VisualEffectBackground(cornerRadius: Self.cornerRadius)
                Color(nsColor: .windowBackgroundColor).opacity(0.55)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(Color(nsColor: .tertiaryLabelColor), lineWidth: 1)
        )
        .padding(Self.windowMargin)
        .onAppear {
            print("[SearchBarView] onAppear — focusing text field")
            isFocused = true
        }
    }
}
