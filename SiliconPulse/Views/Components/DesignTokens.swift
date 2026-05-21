import SwiftUI

enum DesignTokens {
    static let panelWidth: CGFloat = 372
    static let scrollMinHeight: CGFloat = 480
    static let scrollMaxHeight: CGFloat = 600

    static let sectionSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 6
    static let panelPadding: CGFloat = 16
    static let sectionRadius: CGFloat = 10
    static let sparklineHeight: CGFloat = 28

    static func usageTint(_ value: Double) -> Color {
        if value < 50 { return .green }
        if value < 80 { return .orange }
        return .red
    }
}

extension View {
    func nativePanelBackground() -> some View {
        modifier(NativeGlassPanelModifier())
    }

    func nativeSectionBackground() -> some View {
        modifier(NativeGlassSectionModifier(
            shape: RoundedRectangle(cornerRadius: DesignTokens.sectionRadius, style: .continuous)
        ))
    }
}

private struct NativeGlassPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor))
        } else if #available(macOS 26.0, *) {
            content.background {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect)
            }
        } else {
            content.background(.regularMaterial)
        }
    }
}

private struct NativeGlassSectionModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .controlBackgroundColor), in: shape)
        } else if #available(macOS 26.0, *) {
            content.background {
                Color.clear
                    .glassEffect(.regular, in: shape)
            }
        } else {
            content.background(.thickMaterial, in: shape)
        }
    }
}
