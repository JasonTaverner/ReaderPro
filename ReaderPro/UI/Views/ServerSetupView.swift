import SwiftUI

/// Onboarding sheet shown on first launch to help users pick a TTS provider.
/// Offers three options: System voices (no setup), Kokoro (higher quality), and Qwen3 (premium).
struct ServerSetupView: View {

    @ObservedObject var coordinator: TTSServerCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.appPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color.appHighlight)

                    Text("Choose Your Voice Engine")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.appTextPrimary)

                    Text("You can change this anytime in Settings.")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextSecondary)
                }

                // Option cards
                VStack(spacing: 12) {
                    optionCard(
                        icon: "desktopcomputer",
                        title: "System Voices",
                        badge: "Recommended",
                        badgeColor: Color(hex: "4caf50"),
                        description: "Uses built-in macOS voices. Works immediately with no setup required.",
                        action: {
                            selectProvider(.native)
                        }
                    )

                    optionCard(
                        icon: "server.rack",
                        title: "Kokoro TTS",
                        badge: "Higher Quality",
                        badgeColor: Color.appHighlight,
                        description: "Local Python server with natural-sounding voices. Requires server setup.",
                        action: {
                            selectProvider(.kokoro)
                        }
                    )

                    optionCard(
                        icon: "sparkles",
                        title: "Qwen3 TTS",
                        badge: "Premium",
                        badgeColor: Color(hex: "9c27b0"),
                        description: "MLX-powered premium voices with voice cloning. Requires server setup.",
                        action: {
                            selectProvider(.qwen3)
                        }
                    )
                }

                // Dismiss link
                Button {
                    completeSetup()
                } label: {
                    Text("Continue with Current Settings")
                        .font(.caption)
                        .foregroundColor(Color.appTextMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
        }
        .frame(width: 440, height: 520)
    }

    // MARK: - Option Card

    private func optionCard(
        icon: String,
        title: String,
        badge: String,
        badgeColor: Color,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color.appHighlight)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Color.appTextPrimary)

                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeColor)
                            .cornerRadius(4)
                    }

                    Text(description)
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.appTextMuted)
            }
            .padding(14)
            .background(Color.appSecondary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func selectProvider(_ provider: Voice.TTSProvider) {
        UserDefaults.standard.set(provider.rawValue, forKey: SettingsPresenter.defaultProviderKey)
        Task {
            await coordinator.switchProvider(to: provider)
        }
        completeSetup()
    }

    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: "hasCompletedTTSSetup")
        dismiss()
    }
}
