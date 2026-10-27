import SwiftUI
import UIKit

/// Detects iPhone Duo and manages display-specific capabilities
@Observable
@MainActor
final class DeviceCapabilities {
    static let shared = DeviceCapabilities()
    
    private init() {
        updateDetection()
    }
    
    private(set) var cachedIsPhoneDuo: Bool = false
    private(set) var cachedIsInnerDisplay: Bool = false
    
    func updateDetection() {
        let screen = UIScreen.main
        let width = Int(screen.bounds.width * screen.scale)
        let height = Int(screen.bounds.height * screen.scale)
        
        print("📱 Screen detection - width: \(width), height: \(height), scale: \(screen.scale)")
        
        // Inner display: 1878×2670 or Outer display: 1398×2034
        cachedIsPhoneDuo = (width == 1878 && height == 2670) || 
                          (width == 2670 && height == 1878) ||
                          (width == 1398 && height == 2034) ||
                          (width == 2034 && height == 1398)
        
        cachedIsInnerDisplay = (width == 1878 && height == 2670) || (width == 2670 && height == 1878)
        
        print("📱 Detection result - isDuo: \(cachedIsPhoneDuo), isInner: \(cachedIsInnerDisplay)")
    }
    
    // MARK: - Display Detection
    
    /// Whether the device is an iPhone Duo
    var isPhoneDuo: Bool {
        cachedIsPhoneDuo
    }
    
    /// Whether currently using the inner (folded out) display
    var isInnerDisplay: Bool {
        cachedIsInnerDisplay
    }
    
    /// Whether currently using the outer (folded) display
    var isOuterDisplay: Bool {
        guard isPhoneDuo else { return false }
        return !isInnerDisplay
    }
    
    /// Approximate position of the fold line (center of inner display)
    var foldPosition: CGFloat {
        guard isInnerDisplay else { return 0 }
        return UIScreen.main.bounds.width / 2
    }
    
    // MARK: - Layout Recommendations
    
    /// Recommended minimum card width based on display
    var recommendedCardMinWidth: CGFloat {
        if isInnerDisplay {
            // Larger cards for the expansive inner display
            return 380
        } else if isOuterDisplay {
            // Standard cards for outer display
            return 320
        } else {
            // Default for other iPhones
            return 340
        }
    }
    
    /// Recommended horizontal padding
    var recommendedHorizontalPadding: CGFloat {
        if isInnerDisplay {
            // More padding on the larger display
            return 24
        } else {
            return 16
        }
    }
    
    /// Whether to use a two-column layout (for inner display in landscape)
    var shouldUseTwoColumnLayout: Bool {
        guard isInnerDisplay else { return false }
        let orientation = UIDevice.current.orientation
        return orientation.isLandscape || UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }
    
    /// Whether Apple Pencil interaction is likely available
    var supportsPencil: Bool {
        return isInnerDisplay
    }
    
    // MARK: - Fold-Aware Spacing
    
    /// Returns safe spacing to avoid the fold crease
    func foldAwareSpacing(for geometry: GeometryProxy) -> CGFloat {
        guard isInnerDisplay else { return 12 }
        // Add extra spacing if content is near the fold
        return 20
    }
    
    /// Returns grid columns optimized for the current display
    func optimizedGridColumns(spacing: CGFloat = 12) -> [GridItem] {
        if shouldUseTwoColumnLayout {
            // Two equal columns for landscape inner display
            return [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ]
        } else {
            // Adaptive grid
            return [GridItem(.adaptive(minimum: recommendedCardMinWidth), spacing: spacing)]
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies optimal padding for the current device
    func deviceAdaptivePadding() -> some View {
        let capabilities = DeviceCapabilities.shared
        return self.padding(.horizontal, capabilities.recommendedHorizontalPadding)
    }
}
