import SwiftUI

// MARK: - FoodTile
/// One food as a floating paper tile: where-it-lives icon + name, "Prepared · Chicken +1",
/// and the freshness pill (canned: only once its best-by date is close).
struct FoodTile: View {
    @Environment(\.palette) private var palette
    let item: FoodSnapshot
    let now: Date

    var body: some View {
        let fresh = FoodQuery.pill(for: item, now: now)
        let subtitle = FoodQuery.subtitle(for: item)
        let spoken = [item.name, subtitle, fresh == .none ? nil : fresh.spokenLabel]
            .compactMap { $0 }.joined(separator: ", ")
        GlanceTile(symbol: item.place.symbol, title: item.name, subtitle: subtitle, spokenLabel: spoken) {
            FreshnessPill(freshness: fresh, palette: palette)
        }
        .accessibilityHint("Opens this food")
    }
}

// MARK: - FoodSearchField
/// The Food tab's one search box. Matches names, descriptions and every label, forgiving
/// small typos ("chiken") and a few related words ("leftovers", "meat").
struct FoodSearchField: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: Metrics.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(palette.ink2)
                .accessibilityHidden(true)
            TextField("Search food", text: $text)
                .characterLimit($text, FoodQuery.searchLimit)
                .font(fonts.font(.rowBody))
                .foregroundStyle(palette.ink)
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.ink2)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Metrics.m)
        .padding(.vertical, 2)
        .frame(minHeight: 44)
        .background(palette.card, in: RoundedRectangle(cornerRadius: Metrics.corner))
        .overlay(RoundedRectangle(cornerRadius: Metrics.corner).stroke(palette.control, lineWidth: 1))
    }
}
