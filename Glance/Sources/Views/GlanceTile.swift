import SwiftUI

// MARK: - GlanceTile
/// One floating paper tile in a grid: icon + name, a quiet subtitle, and an optional footer.
/// Lists use it for "4 steps" + magnets; Food uses it for "Prepared · Chicken +1" + the pill.
struct GlanceTile<Footer: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let symbol: String
    let title: String
    let subtitle: String
    /// Space kept free at the end of the title (e.g. for the widget pin in the corner).
    let trailingClearance: CGFloat
    /// What VoiceOver reads for the whole tile.
    let spokenLabel: String
    /// Done for now: the tile fades back (lighter card, no shadow, grey title) but stays put.
    let isQuiet: Bool
    let footer: Footer

    /// - Parameters:
    ///   - symbol: SF Symbol shown before the title.
    ///   - title: the tile's name.
    ///   - subtitle: one short quiet line under the name.
    ///   - trailingClearance: room to leave at the end of the title.
    ///   - spokenLabel: VoiceOver text (defaults to "title, subtitle").
    ///   - isQuiet: draw the faded "done for now" look.
    ///   - footer: extra content under the subtitle.
    init(symbol: String, title: String, subtitle: String, trailingClearance: CGFloat = 0,
         spokenLabel: String? = nil, isQuiet: Bool = false, @ViewBuilder footer: () -> Footer) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.trailingClearance = trailingClearance
        self.spokenLabel = spokenLabel ?? "\(title), \(subtitle)"
        self.isQuiet = isQuiet
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            titleLine
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(fonts.font(.caption))
                    .foregroundStyle(palette.ink2)
                    .lineLimit(2)
            }
            footer
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.tileMinHeight, alignment: .topLeading)
        .padding(Metrics.m)
        .paperCard(palette, quiet: isQuiet)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    /// Icon at the start of the line, same size as the name, wrapping as one line of text.
    private var titleLine: some View {
        // Quiet tiles keep ≥4.5:1 text (ink2), so fading never costs legibility.
        let icon = Text(Image(systemName: symbol)).foregroundStyle(isQuiet ? palette.ink2 : palette.marker)
        return (icon + Text(" " + title).foregroundStyle(isQuiet ? palette.ink2 : palette.ink))
            .font(fonts.font(.cardTitle))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.trailing, trailingClearance)
    }
}

/// Tiles with nothing under the subtitle.
extension GlanceTile where Footer == EmptyView {
    /// A tile with no footer.
    init(symbol: String, title: String, subtitle: String, trailingClearance: CGFloat = 0,
         spokenLabel: String? = nil, isQuiet: Bool = false) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, trailingClearance: trailingClearance,
                  spokenLabel: spokenLabel, isQuiet: isQuiet) { EmptyView() }
    }
}

// MARK: - PageHeader
/// A tab's big left-aligned title at the top of its scrolling page ("Glance", "Food").
/// The first time each title appears after the app opens, it writes itself in left to right,
/// like a marker on the board (shown at once with Reduce Motion on).
struct PageHeader: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    /// How much of the title is written (0…1).
    @State private var written: CGFloat = 1

    var body: some View {
        Text(title)
            .font(fonts.font(.appTitle))
            .foregroundStyle(palette.ink)
            .mask(alignment: .leading) {
                GeometryReader { geo in Rectangle().frame(width: geo.size.width * written) }
            }
            .onAppear(perform: writeInOnce)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.l)
            .padding(.top, Metrics.s)
            .padding(.bottom, Metrics.m)
            .accessibilityAddTraits(.isHeader)
    }

    /// Writes the title in, once per title per app launch.
    private func writeInOnce() {
        guard !reduceMotion, WrittenTitles.claim(title) else { return }
        written = 0   // hidden before the first frame (onAppear runs before it's drawn)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))   // let the empty state render first
            withAnimation(.easeInOut(duration: 0.9)) { written = 1 }
        }
    }
}

// MARK: - WrittenTitles
/// Remembers which page titles have already written themselves in since the app opened.
@MainActor
enum WrittenTitles {
    private static var done: Set<String> = []

    /// True the first time a title asks (it may animate); false after that.
    /// - Parameter title: the page title.
    static func claim(_ title: String) -> Bool {
        done.insert(title).inserted
    }
}

// MARK: - EmptyBoard
/// A calm, centred empty state: an icon, a short title, a line of encouragement, and one
/// marker-swoosh action. Lists use a fixed line; Food passes the line of the day.
struct EmptyBoard: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(palette.mustard)
                .accessibilityHidden(true)
            Text(title)
                .font(fonts.font(.cardTitle))
                .foregroundStyle(palette.ink)
            Text(message)
                .font(fonts.font(.rowBody))
                .foregroundStyle(palette.ink2)
                .multilineTextAlignment(.center)
            Button(action: action) { MarkerSwooshLabel(title: actionTitle) }
                .buttonStyle(.plain)
                .padding(.top, 6)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
