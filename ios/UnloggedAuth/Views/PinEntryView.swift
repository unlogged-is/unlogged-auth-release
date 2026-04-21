import SwiftUI

struct PinEntryView: View {
    let pinLength: Int
    let onComplete: (String) -> Void
    var showError: Bool = false
    var title: String = "Enter PIN"

    @State private var enteredDigits: String = ""
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 32) {
            Text(title)
                .font(.loraSubheadline)
                .foregroundStyle(.secondary)

            // Dot indicators
            HStack(spacing: 14) {
                ForEach(0..<pinLength, id: \.self) { index in
                    Circle()
                        .fill(index < enteredDigits.count ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .scaleEffect(index < enteredDigits.count ? 1.1 : 1.0)
                        .animation(.spring(duration: 0.2), value: enteredDigits.count)
                }
            }
            .offset(x: shakeOffset)

            // Numeric keypad
            VStack(spacing: 16) {
                ForEach(0..<3) { row in
                    HStack(spacing: 24) {
                        ForEach(1...3, id: \.self) { col in
                            let digit = row * 3 + col
                            keypadButton(label: "\(digit)") {
                                appendDigit("\(digit)")
                            }
                        }
                    }
                }

                // Bottom row: empty, 0, delete
                HStack(spacing: 24) {
                    Color.clear
                        .frame(width: 72, height: 72)

                    keypadButton(label: "0") {
                        appendDigit("0")
                    }

                    Button {
                        deleteDigit()
                    } label: {
                        Image(systemName: "delete.backward")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(width: 72, height: 72)
                    }
                    .disabled(enteredDigits.isEmpty)
                }
            }
        }
        .onChange(of: showError) { _, isError in
            if isError {
                shakeAndClear()
            }
        }
    }

    private func keypadButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title)
                .fontWeight(.medium)
                .frame(width: 72, height: 72)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func appendDigit(_ digit: String) {
        guard enteredDigits.count < pinLength else { return }
        enteredDigits += digit

        if enteredDigits.count == pinLength {
            let pin = enteredDigits
            // Small delay so the last dot fills before callback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onComplete(pin)
            }
        }
    }

    private func deleteDigit() {
        guard !enteredDigits.isEmpty else { return }
        enteredDigits.removeLast()
    }

    private func shakeAndClear() {
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            shakeOffset = 0
            enteredDigits = ""
        }
    }

    /// Reset the entered digits (call from parent when needed)
    func resetDigits() {
        enteredDigits = ""
    }
}

/// A complete PIN setup flow with length selection and confirmation.
struct PinSetupView: View {
    let onComplete: (String) -> Void
    let onCancel: () -> Void

    @State private var selectedLength: Int = 4
    @State private var step: SetupStep = .chooseAndEnter
    @State private var firstPin: String = ""
    @State private var showMismatch: Bool = false
    @State private var pinEntryId: UUID = UUID()

    private enum SetupStep {
        case chooseAndEnter
        case confirm
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Choose PIN Length")
                .font(.loraSubheadline)
                .foregroundStyle(.secondary)
                .opacity(step == .chooseAndEnter ? 1 : 0)

            Picker("PIN Length", selection: $selectedLength) {
                Text("4 digits").tag(4)
                Text("6 digits").tag(6)
                Text("8 digits").tag(8)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .opacity(step == .chooseAndEnter ? 1 : 0)
            .allowsHitTesting(step == .chooseAndEnter)

            PinEntryView(
                pinLength: selectedLength,
                onComplete: { pin in handlePinEntry(pin) },
                showError: showMismatch,
                title: step == .chooseAndEnter ? "Create your PIN" : "Confirm your PIN"
            )
            .id(pinEntryId)

            if showMismatch {
                Text("PINs don't match — try again")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func handlePinEntry(_ pin: String) {
        switch step {
        case .chooseAndEnter:
            firstPin = pin
            showMismatch = false
            pinEntryId = UUID()
            withAnimation { step = .confirm }

        case .confirm:
            if pin == firstPin {
                onComplete(pin)
            } else {
                showMismatch = true
                pinEntryId = UUID()
                // Go back to first entry
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    firstPin = ""
                    showMismatch = false
                    pinEntryId = UUID()
                    withAnimation { step = .chooseAndEnter }
                }
            }
        }
    }
}
