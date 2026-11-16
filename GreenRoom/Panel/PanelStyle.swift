import PanelKit
import SwiftUI

// Small pieces the panel needs that PanelKit doesn't have yet. They draw with PanelKit's tokens.

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
