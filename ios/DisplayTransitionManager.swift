import SwiftUI
import Combine

/// Monitors iPhone Duo display transitions and provides smooth UI updates
@MainActor
@Observable
final class DisplayTransitionManager {
    static let shared = DisplayTransitionManager()
    
    private(set) var isTransitioning = false
    private(set) var currentDisplayMode: DisplayMode = .standard
    
    enum DisplayMode: Equatable {
        case standard          // Regular iPhone or outer display
        case innerDisplay      // Folded out 7.6" display
        case innerLandscape    // Inner display in landscape
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupDisplayMonitoring()
    }
    
    private func setupDisplayMonitoring() {
        // Monitor for screen size changes (fold/unfold transitions)
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateDisplayMode()
            }
            .store(in: &cancellables)
        
        // Monitor for scene transitions
        NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.updateDisplayMode()
            }
            .store(in: &cancellables)
        
        updateDisplayMode()
    }
    
    private func updateDisplayMode() {
        let capabilities = DeviceCapabilities.shared
        
        let newMode: DisplayMode = {
            if capabilities.isInnerDisplay {
                return capabilities.shouldUseTwoColumnLayout ? .innerLandscape : .innerDisplay
            } else {
                return .standard
            }
        }()
        
        if newMode != currentDisplayMode {
            withAnimation(.smooth(duration: 0.3)) {
                isTransitioning = true
                currentDisplayMode = newMode
            }
            
            // Reset transitioning state after animation
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation {
                    isTransitioning = false
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies iPhone Duo-aware responsive behavior
    func responsiveToDisplayChanges() -> some View {
        self.modifier(DisplayTransitionModifier())
    }
}

private struct DisplayTransitionModifier: ViewModifier {
    @State private var manager = DisplayTransitionManager.shared
    
    func body(content: Content) -> some View {
        content
            .opacity(manager.isTransitioning ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: manager.isTransitioning)
    }
}
