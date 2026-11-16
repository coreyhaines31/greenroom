import PanelKit
import SwiftUI

// Small pieces the panel needs that PanelKit doesn't have yet. They draw with PanelKit's tokens.

extension EnvironmentValues {
    /// PanelKit's theme for the current appearance.
    var roomTheme: PanelTheme { panelThemeOverride ?? PanelTheme.resolve(colorScheme) }
}

/// A compact metal key for buttons inside rows, like Hear Yourself and Test.
struct MiniButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MiniButton(configuration: configuration)
    }

    private struct MiniButton: View {
        let configuration: Configuration
        @Environment(\.roomTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(theme.ink)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(MiniKeyBackground())
                .opacity(configuration.isPressed ? 0.8 : (isEnabled ? 1 : 0.5))
                .contentShape(Rectangle())
                .fixedSize()
        }
    }
}

/// The metal key face behind a mini button or a menu that looks like one.
struct MiniKeyBackground: View {
    @Environment(\.roomTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4)
        shape.fill(LinearGradient(colors: theme.button2, startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(theme.button2Edge, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 0, y: 1)
    }
}

/// A text link in the panel's ink, for small actions like Ignore and Compare.
struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LinkLabel(configuration: configuration)
    }

    private struct LinkLabel: View {
        let configuration: Configuration
        @Environment(\.roomTheme) private var theme

        var body: some View {
            configuration.label
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(theme.ink)
                .underline(color: theme.sub.opacity(0.6))
                .opacity(configuration.isPressed ? 0.6 : 1)
                .contentShape(Rectangle())
        }
    }
}

/// A row icon: an SF Symbol drawn in the panel ink.
struct SymbolTile: View {
    let name: String
    @Environment(\.roomTheme) private var theme

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(theme.ink)
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }
}

/// The outlined strip under the camera, holding the framing tip. Unlike PanelKit's detail strip it
/// wraps, since the tips are full sentences.
struct TipStrip: View {
    let text: String
    @Environment(\.roomTheme) private var theme

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "lightbulb")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(theme.ink2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().strokeBorder(theme.stripOutline, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Framing tip: \(text)")
    }
}

/// A tinted card for a warning that has its own fix, like a headset in call mode.
struct NoticeCard<Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var actions: Actions
    @Environment(\.roomTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(theme.sub)
                .fixedSize(horizontal: false, vertical: true)
            actions.padding(.top, 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.caution.opacity(theme.isDark ? 0.14 : 0.12), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.caution.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}

/// A sentence or two in a section, in the subtitle colour or as a caution.
struct PanelNote: View {
    let text: String
    var caution = false
    @Environment(\.roomTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if caution {
                Circle().fill(theme.caution).frame(width: 6, height: 6)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(caution ? theme.ink : theme.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

/// The hairline between panel sections.
struct PanelHairline: View {
    @Environment(\.roomTheme) private var theme

    var body: some View {
        Rectangle().fill(theme.line).frame(height: 1).accessibilityHidden(true)
    }
}
