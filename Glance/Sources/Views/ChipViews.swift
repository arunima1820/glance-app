import SwiftUI

// MARK: - Chip
/// A small tappable tag. On: filled marker with light text. Off: a control outline (3:1).
/// The state is also spoken ("selected"), so colour is never the only signal.
struct Chip: View {
    @Environment(\.palette) private var palette
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(isOn ? palette.onMarker : palette.ink)
                .padding(.horizontal, Metrics.m)
                .padding(.vertical, 6)
                .background(isOn ? palette.markerDeep : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(isOn ? Color.clear : palette.control, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - ChipRow
/// Chips that wrap onto as many lines as they need. Pass the titles, which ones are on, and
/// what a tap does (multi-select, single-select, or a shortcut).
struct ChipRow: View {
    let titles: [String]
    let isOn: (String) -> Bool
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: Metrics.s) {
            ForEach(titles, id: \.self) { title in
                Chip(title: title, isOn: isOn(title)) { onTap(title) }
            }
        }
    }
}

// MARK: - FlowLayout
/// Lays children left to right, wrapping to a new line when the next one wouldn't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    /// The size all the lines need at the offered width.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    /// Puts each child where `arrange` says.
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = arrange(width: bounds.width, subviews: subviews)
        for (subview, point) in zip(subviews, placed.points) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                          proposal: .unspecified)
        }
    }

    /// Where each child goes for a given width, and the total size used.
    private func arrange(width: CGFloat, subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (points, CGSize(width: widest, height: y + lineHeight))
    }
}
