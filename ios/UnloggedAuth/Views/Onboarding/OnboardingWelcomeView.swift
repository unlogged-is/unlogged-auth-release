import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(.rect(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 12) {
                    Text("unlogged Auth")
                        .font(.loraLargeTitle)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    (Text("by unlogged")
                        .foregroundColor(.white) +
                    Text(".")
                        .foregroundColor(.accent) +
                    Text("is")
                        .foregroundColor(.white))
                        .font(.custom("Lora-Regular", size: 16))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                }
            }

            Spacer()

            Text("Your keys. Your device.")
                .font(.custom("Lora-Regular", size: 20))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .padding(.bottom, 16)

            VStack(spacing: 20) {
                featureRow(icon: "shield.checkered", title: "Fully Offline", subtitle: "No accounts, no tracking, no cloud required", color: .green)
                featureRow(icon: "key.fill", title: "Industry Standard", subtitle: "TOTP & HOTP with SHA-1, SHA-256, SHA-512", color: Color("AccentColor"))
                featureRow(icon: "lock.fill", title: "Encrypted Storage", subtitle: "AES-256-GCM encryption with biometric unlock", color: .purple)
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8)) {
                appeared = true
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.loraSubheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
