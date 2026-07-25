import SwiftUI

/// Liquid Glass surfaces, with a fallback for the macOS versions that do not
/// have them.
///
/// The app deploys to macOS 15.1 but Liquid Glass (`glassEffect`,
/// `GlassEffectContainer`, `buttonStyle(.glass)`) only exists from macOS 26.
/// Rather than sprinkle `if #available` through every view, the whole UI goes
/// through the helpers here: on 26+ they render real glass, below it they fall
/// back to `.ultraThinMaterial`, which is the closest thing the older system
/// offers and keeps the layout identical.
///
/// Reduced Transparency is honoured explicitly. The system already frosts
/// glass more heavily when that setting is on, but the fallback material would
/// not be affected at all, so the modifier opts out of glass entirely and lets
/// the material path handle it — one behaviour on every OS version.

// MARK: - Surfaces

private struct GlassSurface<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let shape: S
    let tint: Color?
    let isInteractive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            content.glassEffect(glass, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if isInteractive {
            glass = glass.interactive()
        }
        return glass
    }
}

extension View {
    /// A glass surface clipped to `shape`.
    func glassSurface<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, isInteractive: interactive))
    }

    /// A glass panel — the default surface for cards, rows and sections.
    func glassPanel(
        cornerRadius: CGFloat = 12,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        glassSurface(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            interactive: interactive
        )
    }

    /// A glass capsule — for floating controls such as the recording indicator.
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        glassSurface(in: Capsule(), tint: tint, interactive: interactive)
    }
}

// MARK: - Button styles

extension View {
    /// Secondary actions.
    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Primary action of a screen. Opaque, so it stays the obvious target.
    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Container

/// Groups sibling glass surfaces so they blend and morph as one shape instead
/// of rendering — and compositing — separately.
///
/// Below macOS 26 it is a passthrough: the fallback material has nothing to
/// merge, and wrapping the content in an extra layout container would shift it.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat?
    @ViewBuilder var content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
