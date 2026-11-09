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
    /// Shortest a grid tile (list, food, or dashed "New" tile) may be.
    static let tileMinHeight: CGFloat = 72
    /// Room kept free in a tile's top-right corner for the widget pin.
    static let pinClearance: CGFloat = 22
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

    /// The card surface used for tiles: card fill, hairline border, soft corner, and a slight
    /// drop shadow so tiles float off the paper like real tiles. Quiet (done for now): a
    /// see-through fill and no shadow, so the tile sits back against the board.
    /// - Parameters:
    ///   - palette: the active palette.
    ///   - quiet: draw the faded look.
    func paperCard(_ palette: Palette, quiet: Bool = false) -> some View {
        self
            .background(palette.card.opacity(quiet ? 0.45 : 1), in: RoundedRectangle(cornerRadius: Metrics.corner))
            .overlay(RoundedRectangle(cornerRadius: Metrics.corner).stroke(palette.hairline, lineWidth: 1))
            .shadow(color: palette.ink.opacity(quiet ? 0 : 0.10), radius: 6, x: 0, y: 3)
    }

    /// Nav bar and tab bar take the paper/chalkboard colour (no system grey band).
    /// - Parameter palette: the active palette.
    func paperBars(_ palette: Palette) -> some View {
        self
            .toolbarBackground(palette.paper, for: .navigationBar, .tabBar)
    }

    /// A row inside a paper `List` card: card fill and hairline separators.
    /// - Parameter palette: the active palette.
    func paperListRow(_ palette: Palette) -> some View {
        self
            .listRowBackground(palette.card)
            .listRowSeparatorTint(palette.hairline)
    }

    /// Paper (light) / chalkboard (dark) background behind a whole screen.
    /// - Parameter palette: the active palette.
    func paperBackground(_ palette: Palette) -> some View {
        background(palette.paper.ignoresSafeArea())
    }
}

// MARK: - Motion
/// Shared animation timings.
enum Motion {
    /// How long iOS takes to put a long-pressed tile back. Anything a long-press menu choice
    /// triggers (an alert, a burst, a wipe) waits this long, or it plays under the lifted
    /// tile or gets dropped.
    static let afterMenu: Duration = .milliseconds(350)
}

// MARK: - Character limit
extension View {
    /// Stops a text field growing past `limit` characters while typing or pasting. (Saving
    /// still cleans and trims through `TextLimits.clamp`.)
    /// - Parameters:
    ///   - text: the field's text.
    ///   - limit: most characters allowed.
    func characterLimit(_ text: Binding<String>, _ limit: Int) -> some View {
        onChange(of: text.wrappedValue) { _, new in
            if new.count > limit { text.wrappedValue = String(new.prefix(limit)) }
        }
    }
}

// MARK: - Confirm delete
extension View {
    /// The app's one way to confirm a delete: a standard centred iOS alert that dims the whole
    /// screen, with a red delete button and a cancel button.
    /// - Parameters:
    ///   - title: the question ("Delete this list?").
    ///   - isPresented: shows the alert while true.
    ///   - message: one calm line under the title.
    ///   - deleteLabel: the red button's wording.
    ///   - keepLabel: the cancel button's wording.
    ///   - onDelete: runs when the user confirms.
    func confirmDelete(_ title: String, isPresented: Binding<Bool>, message: String,
                       deleteLabel: String = "Delete", keepLabel: String = "Cancel",
                       onDelete: @escaping () -> Void) -> some View {
        alert(title, isPresented: isPresented) {
            Button(deleteLabel, role: .destructive, action: onDelete)
            Button(keepLabel, role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

// MARK: - PlannedToggle
/// A greyed-out switch for a feature that's coming later, with one line saying what it will
/// do. Always off and can't be turned on, so it never surprises anyone.
struct PlannedToggle: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let title: String
    let detail: String

    var body: some View {
        Toggle(isOn: .constant(false)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(fonts.font(.rowBody)).foregroundStyle(palette.ink)
                Text(detail).font(fonts.font(.caption)).foregroundStyle(palette.ink2)
            }
        }
        .disabled(true)
        .accessibilityHint("Coming in a future update")
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
/// The dashed "+ New …" tile that sits last in a grid (Lists and Food).
struct DashedTile: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let title: String

    var body: some View {
        (Text(Image(systemName: "plus")) + Text(" " + title))
            .font(fonts.font(.cardTitle))
            .foregroundStyle(palette.ink2)
            .frame(maxWidth: .infinity, minHeight: Metrics.tileMinHeight)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.corner)
                    .stroke(palette.ink2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .contentShape(Rectangle())
    }
}

// MARK: - SwooshLabel
/// The "all done!" label; its done state goes quiet ("Done. Tap to bring it back.").
struct SwooshLabel: View {
    let done: Bool

    var body: some View {
        MarkerSwooshLabel(title: done ? "Done. Tap to bring it back." : "all done!",
                          showsCheck: !done, quiet: done)
    }
}

// MARK: - MarkerSwooshLabel
/// Handwritten action text with a drawn underline, like a note on the board. The app's
/// one button style for primary actions ("all done!", "Create a list", "used it up!", Save, Edit).
struct MarkerSwooshLabel: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let title: String
    var showsCheck = false
    /// Smaller, ink2 text and a faded swoosh (e.g. the done state).
    var quiet = false

    var body: some View {
        HStack(spacing: 5) {
            if showsCheck {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy))
            }
            Text(title).font(quiet ? fonts.font(.caption) : fonts.font(.button))
        }
        .foregroundStyle(quiet ? palette.ink2 : palette.marker)
        .padding(.bottom, 9)
        .overlay(alignment: .bottom) {
            Swoosh()
                .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .foregroundStyle(quiet ? palette.ink2.opacity(0.35) : palette.marker)
                .frame(height: 8)
        }
        .contentShape(Rectangle())
    }
}

/// A slightly wavy hand-drawn underline spanning its rect.
struct Swoosh: Shape {
    /// Path from lower-left to upper-right with a gentle S-curve.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.67))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.98, y: rect.minY + h * 0.33),
                      control1: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.22),
                      control2: CGPoint(x: rect.minX + w * 0.55, y: rect.minY + h * 0.89))
        return path
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

// MARK: - Current day
/// The moment views judge "done today" against. RootTabView refreshes it when the app becomes
/// active and when the calendar day changes, so ticks from yesterday visibly clear (and a tap
/// after midnight ticks rather than un-ticks).
private struct GlanceNowKey: EnvironmentKey {
    static let defaultValue = Date()
}

extension EnvironmentValues {
    /// See `GlanceNowKey`.
    var glanceNow: Date {
        get { self[GlanceNowKey.self] }
        set { self[GlanceNowKey.self] = newValue }
    }
}

