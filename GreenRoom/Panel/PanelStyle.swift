import PanelKit
import SwiftUI

// Small pieces the panel needs that PanelKit doesn't have yet. They draw with PanelKit's tokens.

/// A row icon: an SF Symbol drawn in the panel ink.
struct SymbolTile: View {
    let name: String
    @Environment(\.panelTheme) private var theme

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
    @Environment(\.panelTheme) private var theme

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
    @Environment(\.panelTheme) private var theme

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
    @Environment(\.panelTheme) private var theme

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
    @Environment(\.panelTheme) private var theme

    var body: some View {
        Rectangle().fill(theme.line).frame(height: 1).accessibilityHidden(true)
    }
}
