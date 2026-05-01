import SwiftUI

struct OnboardingTutorialView: View {
    let onFinish: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.accent)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Text("You're All Set!")
                    .font(.loraTitle)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 20) {
                    tutorialStep(number: 1, icon: "plus.circle.fill", text: "Tap + to add a token via QR code or manual entry")
                    tutorialStep(number: 2, icon: "doc.on.doc.fill", text: "Tap a code to copy it to your clipboard")
                    tutorialStep(number: 3, icon: "folder.fill", text: "Organize tokens into groups for easy access")
                    tutorialStep(number: 4, icon: "gearshape.fill", text: "Visit Settings to manage backups and security")
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }

            Spacer()

            Button {
                onFinish()
            } label: {
                Text("Start Using unlogged Auth")
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

    private func tutorialStep(number: Int, icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 40, height: 40)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
