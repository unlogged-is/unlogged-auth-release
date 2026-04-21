import SwiftUI

enum FontRegistration {
    static func registerFonts() {
        // Fonts are registered automatically via UIAppFonts in Info.plist
    }
}

extension Font {
    static func lora(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black:
            return .custom("Lora-Bold", size: size)
        case .semibold:
            return .custom("Lora-SemiBold", size: size)
        case .medium:
            return .custom("Lora-Medium", size: size)
        default:
            return .custom("Lora-Regular", size: size)
        }
    }

    static var loraTitle: Font {
        .custom("Lora-Bold", size: 28, relativeTo: .title)
    }

    static var loraLargeTitle: Font {
        .custom("Lora-Bold", size: 34, relativeTo: .largeTitle)
    }

    static var loraHeadline: Font {
        .custom("Lora-SemiBold", size: 17, relativeTo: .headline)
    }

    static var loraSubheadline: Font {
        .custom("Lora-Medium", size: 15, relativeTo: .subheadline)
    }

    static var loraTokenName: Font {
        .custom("Lora-SemiBold", size: 16, relativeTo: .subheadline)
    }
}
