import SwiftUI

// MARK: - MarkerDots
/// A small burst of marker / chalk dots popping out from a point and fading: the "you did it"
/// moment after "all done!" on a list. Purely decorative: never takes taps, hidden from
/// VoiceOver. Callers skip it with Reduce Motion.
struct MarkerDots: View {
    @Environment(\.palette) private var palette
    /// Runs once the burst has faded.
    var onFinish: () -> Void = {}
    @State private var playing = false

    /// Each dot's flight (points from the centre), size, and colour.
    static let dots: [DotFlight] = [
        DotFlight(dx: -46, dy: -30, size: 7, tone: .marker), DotFlight(dx: -18, dy: -48, size: 5, tone: .mustard),
        DotFlight(dx: 14, dy: -52, size: 8, tone: .avocado), DotFlight(dx: 44, dy: -34, size: 6, tone: .sky),
        DotFlight(dx: 56, dy: -6, size: 5, tone: .marker), DotFlight(dx: -58, dy: -4, size: 6, tone: .avocado),
        DotFlight(dx: 30, dy: -62, size: 4, tone: .mustard),
    ]
    /// How long one burst lasts.
    static let duration: TimeInterval = 0.8

    var body: some View {
        ZStack {
            ForEach(Self.dots.indices, id: \.self) { index in
                dot(Self.dots[index])
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

    /// One dot: flies out along its path, then fades over the last part of the flight.
    private func dot(_ flight: DotFlight) -> some View {
        Circle()
            .fill(color(flight.tone))
            .frame(width: flight.size, height: flight.size * 0.85)   // a touch uneven, like a dab
            .keyframeAnimator(initialValue: 0.0, trigger: playing) { view, progress in
                view
                    .offset(x: flight.dx * progress, y: flight.dy * progress)
                    .opacity(progress == 0 ? 0 : min(1, (1 - progress) / 0.4))
            } keyframes: { _ in
                CubicKeyframe(1.0, duration: Self.duration)
            }
    }

    /// The palette colour for a tone (bright chalk on the board, marker on paper).
    private func color(_ tone: DotFlight.Tone) -> Color {
        switch tone {
        case .marker: return palette.marker
        case .mustard: return palette.mustard
        case .avocado: return palette.avocado
        case .sky: return palette.sky
        }
    }
}

// MARK: - DustCloud
/// A soft puff of board dust that swells and fades at its centre (the same chalk dust the
/// duster leaves on food), behind the marker dots.
struct DustCloud: View {
    @Environment(\.palette) private var palette
    @State private var playing = false

    /// One puff: how far it drifts (points) and how big it is.
    struct Puff: Equatable {
        let dx: CGFloat
        let dy: CGFloat
        let size: CGFloat
    }

    /// The puffs, spread around the centre.
    static let puffs: [Puff] = [
        Puff(dx: -16, dy: -6, size: 30), Puff(dx: 12, dy: -12, size: 36),
        Puff(dx: 0, dy: 8, size: 26), Puff(dx: 20, dy: 6, size: 22),
    ]

    var body: some View {
        ZStack {
            ForEach(Self.puffs.indices, id: \.self) { index in
                puff(Self.puffs[index])
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { playing = true }
    }

    /// One puff: grows a little, drifts up and out, and fades in then out.
    private func puff(_ flight: Puff) -> some View {
        Circle()
            .fill(palette.ink2.opacity(0.28))
            .frame(width: flight.size, height: flight.size)
            .blur(radius: 6)
            .keyframeAnimator(initialValue: 0.0, trigger: playing) { view, progress in
                view
                    .scaleEffect(0.5 + progress)
                    .offset(x: flight.dx * (0.5 + progress), y: flight.dy * (0.5 + progress) - 10 * progress)
                    .opacity(sin(progress * .pi))
            } keyframes: { _ in
                CubicKeyframe(1.0, duration: MarkerDots.duration)
            }
    }
}

// MARK: - DoneBurst
/// The whole "list finished" moment: a puff of dust with marker / chalk dots popping out of it.
/// Used by "all done!" on a list and by a tile's long-press "Mark all done".
struct DoneBurst: View {
    /// Runs once the dots have faded.
    var onFinish: () -> Void = {}

    var body: some View {
        ZStack {
            DustCloud()
            MarkerDots(onFinish: onFinish)
        }
    }
}

// MARK: - DotFlight
/// Where one dot goes: an offset from the burst's centre, its size, and its colour role.
struct DotFlight: Equatable {
    /// The palette roles the dots use.
    enum Tone: Equatable { case marker, mustard, avocado, sky }

    let dx: CGFloat
    let dy: CGFloat
    let size: CGFloat
    let tone: Tone
}
