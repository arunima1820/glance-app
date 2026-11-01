import SwiftUI

// MARK: - OnboardingView  (shown on very first launch)
/// One-screen, skippable intro on the paper surface.
/// Message: tiny lists you look at; checking things off is optional.
struct OnboardingView: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 36) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(palette.marker)
                .accessibilityHidden(true)
            VStack(spacing: 14) {
                Text("\(AppInfo.displayName) holds tiny lists you look at.")
                    .font(fonts.font(.screenTitle))
                    .foregroundStyle(palette.ink)
                Text("Cross things off if you like. Nothing is ever overdue.")
                    .font(fonts.font(.rowBody))
                    .foregroundStyle(palette.ink2)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            Spacer()
            startButton
            Button("Skip", action: onDismiss)
                .font(fonts.font(.caption))
                .foregroundStyle(palette.ink2)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .paperBackground(palette)
    }

    /// The one sticker-styled primary action on this screen.
    private var startButton: some View {
        Button(action: onDismiss) {
            Text("Get started")
                .font(fonts.font(.button))
                .foregroundStyle(palette.onMarker)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(palette.markerDeep, in: RoundedRectangle(cornerRadius: 10))
                .stickerStyle(palette)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
    }
}
