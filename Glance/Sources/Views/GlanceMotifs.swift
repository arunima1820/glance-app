import SwiftUI

// MARK: - Metrics
/// The one spacing scale (4 / 8 / 12 / 16 / 24) and corner radius used across screens.
enum Metrics {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let corner: CGFloat = 14
}

// MARK: - Fridge & Marker motifs
/// Small reusable pieces of the locked look (design-tokens-locked.md → Motifs).
/// All colors come from the resolved `Palette`, so a palette swap restyles them too.

extension View {
    /// Sticker border + 2pt hard shadow. For primary actions only, used sparingly.
    /// - Parameter palette: the active palette.
    func stickerStyle(_ palette: Palette) -> some View {
        self
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.ink, lineWidth: 1.5))
            .background(RoundedRectangle(cornerRadius: 10).fill(palette.ink).offset(x: 2, y: 2))
    }

    /// The card surface used for list tiles: card fill, hairline border, soft corner, and a
    /// slight drop shadow so tiles float off the paper like real tiles.
    /// - Parameter palette: the active palette.
    func paperCard(_ palette: Palette) -> some View {
        self
            .background(palette.card, in: RoundedRectangle(cornerRadius: Metrics.corner))
            .overlay(RoundedRectangle(cornerRadius: Metrics.corner).stroke(palette.hairline, lineWidth: 1))
            .shadow(color: palette.ink.opacity(0.10), radius: 6, x: 0, y: 3)
    }

    /// Nav bar and tab bar take the paper/chalkboard colour (no system grey band).
    /// - Parameter palette: the active palette.
    func paperBars(_ palette: Palette) -> some View {
        self
            .toolbarBackground(palette.paper, for: .navigationBar, .tabBar)
    }

    /// Paper (light) / chalkboard (dark) background behind a whole screen.
    /// - Parameter palette: the active palette.
    func paperBackground(_ palette: Palette) -> some View {
        background(palette.paper.ignoresSafeArea())
    }
}

// MARK: - MagnetDot
/// A category "magnet": colored dot always paired with its name (color is never the only signal).
struct MagnetDot: View {
    @Environment(\.palette) private var palette
    let name: String
    let colorToken: String

    var body: some View {
        let entry = CategoryPalette.entry(for: colorToken)
        HStack(spacing: 4) {
            Circle()
                .fill(entry.light)   // the bright tone reads on paper and chalkboard alike
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(palette.ink.opacity(0.35), lineWidth: 0.5))
            Text(name)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(palette.ink2)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Category \(name)")
    }
}

// MARK: - DashedTile
/// The dashed "New list" tile that sits last in the Lists grid.
struct DashedTile: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let title: String

    var body: some View {
        (Text(Image(systemName: "plus")) + Text(" " + title))
            .font(fonts.font(.cardTitle))
            .foregroundStyle(palette.ink2)
            .frame(maxWidth: .infinity, minHeight: 72)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.corner)
                    .stroke(palette.ink2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Marker toolbar items
extension ToolbarContent {
    /// On iOS 26 the system wraps toolbar items in a Liquid Glass capsule; marker-swoosh
    /// buttons draw their own look, so that shared background is hidden for them.
    @ToolbarContentBuilder func withoutSharedGlass() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

