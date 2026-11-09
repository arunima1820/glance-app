import SwiftUI

// MARK: - DusterWipe
/// A little hand-drawn board duster that wipes across its area in a zigzag, the way a hand
/// cleans a whiteboard: food that's used up gets wiped off the board (lists celebrate with
/// `MarkerDots` instead). On the chalkboard it leaves a faint chalk-dust puff. Purely
/// decorative: never takes taps, hidden from VoiceOver. Callers skip it with Reduce Motion.
struct DusterWipe: View {
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme
    /// Runs once the wipe has finished.
    var onFinish: () -> Void = {}
    @State private var playing = false

    /// Where the duster passes, as fractions of the area (x, y) and its tilt in degrees:
    /// in from the left, then back and forth, moving down, and out to the right.
    static let stops: [DusterPose] = [
        DusterPose(x: -0.15, y: 0.12, angle: -8), DusterPose(x: 1.05, y: 0.26, angle: 7),
        DusterPose(x: 0.0, y: 0.42, angle: -7), DusterPose(x: 1.0, y: 0.58, angle: 6),
        DusterPose(x: 0.05, y: 0.74, angle: -6), DusterPose(x: 1.25, y: 0.9, angle: 8),
    ]
    /// Time for each stroke of the zigzag.
    static let stroke: TimeInterval = 0.2
    /// The whole wipe.
    static var duration: TimeInterval { stroke * Double(stops.count - 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if scheme == .dark { ChalkDust(color: palette.ink, playing: playing) }
                movingDuster(in: geo.size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            playing = true
            try? await Task.sleep(for: .seconds(Self.duration))
            onFinish()
        }
    }

    /// The duster following the zigzag keyframes across an area of `size`.
    private func movingDuster(in size: CGSize) -> some View {
        DusterArt(palette: palette)
            .frame(width: 56, height: 44)
            .keyframeAnimator(initialValue: Self.stops[0], trigger: playing) { duster, pose in
                duster
                    .rotationEffect(.degrees(pose.angle))
                    .position(x: pose.x * size.width, y: pose.y * size.height)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    CubicKeyframe(Self.stops[1].x, duration: Self.stroke)
                    CubicKeyframe(Self.stops[2].x, duration: Self.stroke)
                    CubicKeyframe(Self.stops[3].x, duration: Self.stroke)
                    CubicKeyframe(Self.stops[4].x, duration: Self.stroke)
                    CubicKeyframe(Self.stops[5].x, duration: Self.stroke)
                }
                KeyframeTrack(\.y) {
                    CubicKeyframe(Self.stops[1].y, duration: Self.stroke)
                    CubicKeyframe(Self.stops[2].y, duration: Self.stroke)
                    CubicKeyframe(Self.stops[3].y, duration: Self.stroke)
                    CubicKeyframe(Self.stops[4].y, duration: Self.stroke)
                    CubicKeyframe(Self.stops[5].y, duration: Self.stroke)
                }
                KeyframeTrack(\.angle) {
                    CubicKeyframe(Self.stops[1].angle, duration: Self.stroke)
                    CubicKeyframe(Self.stops[2].angle, duration: Self.stroke)
                    CubicKeyframe(Self.stops[3].angle, duration: Self.stroke)
                    CubicKeyframe(Self.stops[4].angle, duration: Self.stroke)
                    CubicKeyframe(Self.stops[5].angle, duration: Self.stroke)
                }
            }
    }
}

// MARK: - DusterPose
/// Where the duster is at one moment: position as fractions of the area, tilt in degrees.
struct DusterPose: Equatable {
    var x: Double
    var y: Double
    var angle: Double
}

// MARK: - DusterArt
/// The duster itself, drawn with slightly wobbly marker outlines: a wooden handle on top,
/// a felt pad with a few stripes underneath.
struct DusterArt: View {
    let palette: Palette

    var body: some View {
        VStack(spacing: -2) {
            WobblyBlock(wobble: 2)
                .fill(palette.mustard)
                .overlay(WobblyBlock(wobble: 2).stroke(palette.ink, style: Self.line))
                .padding(.horizontal, 4)
            WobblyBlock(wobble: 1.5)
                .fill(palette.ink2)
                .overlay(feltStripes)
                .overlay(WobblyBlock(wobble: 1.5).stroke(palette.ink, style: Self.line))
        }
    }

    private static let line = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

    /// Short vertical felt lines.
    private var feltStripes: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { _ in
                Capsule().fill(palette.paper.opacity(0.55)).frame(width: 1.5, height: 8)
            }
        }
    }
}

// MARK: - WobblyBlock
/// A rounded block whose sides bow a little, like a shape drawn by hand.
struct WobblyBlock: Shape {
    /// How far each side bows (points).
    var wobble: CGFloat

    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + 3, y: r.minY + 1))
        path.addQuadCurve(to: CGPoint(x: r.maxX - 2, y: r.minY + 2), control: CGPoint(x: r.midX, y: r.minY - wobble))
        path.addQuadCurve(to: CGPoint(x: r.maxX - 1, y: r.maxY - 2), control: CGPoint(x: r.maxX + wobble, y: r.midY))
        path.addQuadCurve(to: CGPoint(x: r.minX + 2, y: r.maxY - 1), control: CGPoint(x: r.midX, y: r.maxY + wobble))
        path.addQuadCurve(to: CGPoint(x: r.minX + 3, y: r.minY + 1), control: CGPoint(x: r.minX - wobble, y: r.midY))
        path.closeSubpath()
        return path
    }
}

// MARK: - ChalkDust
/// Faint chalk-dust puffs left behind at each turn of the zigzag (chalkboard only).
struct ChalkDust: View {
    let color: Color
    let playing: Bool

    var body: some View {
        GeometryReader { geo in
            ForEach(1..<DusterWipe.stops.count - 1, id: \.self) { index in
                let stop = DusterWipe.stops[index]
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: 34, height: 34)
                    .blur(radius: 6)
                    .keyframeAnimator(initialValue: 0.0, trigger: playing) { puff, fade in
                        puff.opacity(fade).scaleEffect(0.6 + fade * 0.8)
                    } keyframes: { _ in
                        LinearKeyframe(0.0, duration: DusterWipe.stroke * Double(index))   // wait for the duster
                        CubicKeyframe(1.0, duration: 0.12)
                        CubicKeyframe(0.0, duration: 0.6)
                    }
                    .position(x: min(max(stop.x, 0.08), 0.92) * geo.size.width, y: stop.y * geo.size.height)
            }
        }
    }
}
