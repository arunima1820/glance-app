import SwiftUI

// MARK: - OnboardingView  (Screen shown on very first launch)
/// One-screen, skippable intro.
/// Message: "Glance holds tiny lists you look at. There's nothing to check off."
struct OnboardingView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            GlanceColors.background.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Text("👀")
                    .font(.system(size: 72))
                    .accessibilityHidden(true)

                VStack(spacing: 16) {
                    Text("Glance holds tiny lists\nyou look at.")
                        .font(GlanceFonts.title)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(GlanceColors.primaryText)

                    Text("There's nothing to check off.")
                        .font(GlanceFonts.body)
                        .foregroundStyle(GlanceColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()

                Button(action: onDismiss) {
                    Text("Get started")
                        .font(GlanceFonts.label)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(GlancePrimaryButtonStyle())
                .padding(.horizontal, 32)

                Button(action: onDismiss) {
                    Text("Skip")
                        .font(GlanceFonts.caption)
                        .foregroundStyle(GlanceColors.secondaryText)
                }
                .padding(.bottom, 24)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
