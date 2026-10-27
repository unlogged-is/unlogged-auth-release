import SwiftUI

/// Settings section that appears only on iPhone Duo
struct PhoneDuoSettingsSection: View {
    let deviceCapabilities = DeviceCapabilities.shared
    
    var body: some View {
        if deviceCapabilities.isPhoneDuo {
            Section {
                HStack {
                    Image(systemName: "iphone.gen3")
                        .foregroundStyle(.accent)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iPhone Duo")
                            .font(.headline)
                        Text(currentDisplayDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
                .padding(.vertical, 4)
                
                if deviceCapabilities.isInnerDisplay {
                    Label {
                        Text("Large display optimizations active")
                    } icon: {
                        Image(systemName: "rectangle.expand.vertical")
                            .foregroundStyle(.accent)
                    }
                    .font(.subheadline)
                }
                
                if deviceCapabilities.supportsPencil && deviceCapabilities.isInnerDisplay {
                    Label {
                        Text("Apple Pencil supported")
                    } icon: {
                        Image(systemName: "applepencil")
                            .foregroundStyle(.accent)
                    }
                    .font(.subheadline)
                }
            } header: {
                Text("Device")
            } footer: {
                Text(optimizationFooter)
            }
        }
    }
    
    private var currentDisplayDescription: String {
        if deviceCapabilities.isInnerDisplay {
            if deviceCapabilities.shouldUseTwoColumnLayout {
                return "7.6\" Inner Display (Landscape)"
            } else {
                return "7.6\" Inner Display"
            }
        } else if deviceCapabilities.isOuterDisplay {
            return "5.4\" Outer Display"
        } else {
            return "Standard Display"
        }
    }
    
    private var optimizationFooter: String {
        if deviceCapabilities.isInnerDisplay {
            return "Your app layout is optimized for the large foldable display with enhanced spacing and larger touch targets."
        } else {
            return "Open your iPhone Duo for an enhanced experience with larger layouts."
        }
    }
}

// Usage in SettingsView - add this section at the top of your settings
extension View {
    func withPhoneDuoSettings() -> some View {
        Group {
            PhoneDuoSettingsSection()
            self
        }
    }
}
