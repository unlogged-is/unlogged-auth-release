import SwiftUI

struct TokenCardView: View {
    let token: OTPToken
    let iconFetcher: ServiceIconFetcher
    let isCopied: Bool
    let onCopy: () -> Void
    let onIncrement: () -> Void

    @State private var currentCode: String = ""
    @State private var nextCode: String = ""
    @State private var progress: Double = 0
    @State private var remainingSeconds: Int = 0
    @State private var timer: Timer?

    var body: some View {
        Button {
            onCopy()
        } label: {
            HStack(spacing: 14) {
                tokenIcon
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(token.issuer.isEmpty ? "Unknown" : token.issuer)
                        .font(.loraTokenName)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !token.account.isEmpty {
                        Text(token.account)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(OTPGenerator.formatCode(currentCode))
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(isCopied ? .accent : .primary)
                        .contentTransition(.numericText())

                    if token.type == .totp {
                        countdownIndicator
                    } else {
                        Button {
                            onIncrement()
                            updateCode()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                                .foregroundStyle(.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .themedSecondaryBackground()
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isCopied ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isCopied)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    @ViewBuilder
    private var tokenIcon: some View {
        if let iconURL = iconFetcher.iconURL(for: token.issuer) {
            AsyncImage(url: iconURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        let color = tokenColor
        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
            Image(systemName: token.iconSymbol ?? "key.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private var tokenColor: Color {
        if let colorName = token.iconColor {
            switch colorName {
            case "red": return .red
            case "orange": return .orange
            case "yellow": return .yellow
            case "green": return .green
            case "blue": return .blue
            case "purple": return .purple
            case "pink": return .pink
            case "teal": return .teal
            default: return .accent
            }
        }
        let hash = abs(token.issuer.hashValue)
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .teal, .indigo, .mint]
        return colors[hash % colors.count]
    }

    private var countdownIndicator: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                Text("Next")
                    .font(.system(.caption))
                    .foregroundStyle(.tertiary)
                Text(OTPGenerator.formatCode(nextCode))
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Circle()
                    .stroke(progressColor.opacity(0.2), lineWidth: 2.5)
                    .frame(width: 22, height: 22)

                Circle()
                    .trim(from: 0, to: max(0, 1 - progress))
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
                    .animation(.linear(duration: 0.5), value: progress)

                Text("\(remainingSeconds)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(progressColor)
            }
        }
    }

    private var progressColor: Color {
        if progress > 0.8 {
            return .red
        } else if progress > 0.6 {
            return .orange
        }
        return .accent
    }

    private func startTimer() {
        updateCode()
        updateProgress()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                updateProgress()
                let newCode = OTPGenerator.generate(for: token)
                let newNextCode = OTPGenerator.generateNext(for: token)
                if newCode != currentCode {
                    withAnimation(.snappy(duration: 0.2)) {
                        currentCode = newCode
                        nextCode = newNextCode
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateCode() {
        currentCode = OTPGenerator.generate(for: token)
        nextCode = OTPGenerator.generateNext(for: token)
    }

    private func updateProgress() {
        progress = OTPGenerator.progress(for: token.period)
        remainingSeconds = Int(OTPGenerator.remainingSeconds(for: token.period))
    }
}
