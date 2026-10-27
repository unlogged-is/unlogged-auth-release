# iPhone Duo Optimizations

This document outlines the optimizations made to unlogged Auth for the iPhone Duo.

## Device Overview

The iPhone Duo is Apple's first foldable iPhone featuring:
- **Inner Display**: 7.6" OLED (1878×2670 @ 430ppi) with nano-texture finish
- **Outer Display**: 5.4" OLED (1398×2034 @ 460ppi)
- **Both displays**: Dynamic Island, ProMotion (120Hz), Always-On
- **Apple Pencil Support**: USB-C (inner display only)
- **Form Factor**: Foldable design (6.48" × 4.64" open, 3.31" × 4.64" closed)

## Optimizations Implemented

### 1. Device Detection (`DeviceCapabilities.swift`)
- Automatic detection of iPhone Duo based on screen resolution
- Distinguishes between inner (7.6") and outer (5.4") displays
- Provides layout recommendations based on current display
- Detects fold position for crease-aware layouts
- Apple Pencil capability detection

### 2. Adaptive Layouts
**TokensListView, GroupsView, GroupDetailView:**
- Dynamic grid columns: adaptive on outer display, optimized two-column on inner landscape
- Increased card minimum width (380pt) on inner display vs standard (340pt)
- Enhanced spacing (16-20pt) to avoid fold crease
- Responsive padding: 24pt on inner, 16pt on standard displays

### 3. Enhanced Visual Hierarchy (`TokenCardView.swift`)
**Inner Display Enhancements:**
- Larger icons: 52pt (vs 44pt standard)
- Bigger card padding: 20pt (vs 16pt)
- Enhanced code font: `.title` weight on inner display
- Improved touch targets for better interaction

### 4. TabView Optimization (`ContentView.swift`)
- Automatic sidebar-style tabs on inner display in landscape
- Standard tab bar on outer display and portrait orientation
- Seamless transitions between display modes

### 5. QR Scanner Enhancements (`QRScannerView.swift`)
- Hint overlay on outer display: "Unfold for larger view"
- Camera preview optimized for both display sizes
- Continuous operation during fold/unfold transitions

### 6. Display Transition Management (`DisplayTransitionManager.swift`)
- Monitors fold/unfold events
- Smooth UI transitions with subtle opacity changes
- State preservation across display switches
- Orientation-aware display mode detection

## Best Practices for iPhone Duo

### Layout Guidelines
1. **Avoid the Fold Crease**: On inner display, content spacing is increased to 20pt to minimize visual disruption at the fold line
2. **Responsive Grid**: Use `DeviceCapabilities.optimizedGridColumns()` for automatic column optimization
3. **Adaptive Padding**: Use `.deviceAdaptivePadding()` modifier for display-appropriate margins

### Display-Specific UX
- **Outer Display**: Compact, efficient layouts optimized for one-handed use
- **Inner Display (Portrait)**: Tablet-like experience with larger content
- **Inner Display (Landscape)**: Two-column layouts and sidebar navigation

### Transition Handling
- UI adapts automatically when users fold/unfold the device
- No user interaction required for layout changes
- Smooth animations prevent jarring transitions
- Content state is preserved across display changes

## Testing Recommendations

### On iPhone Duo Hardware
1. Test fold/unfold transitions while:
   - Viewing token list
   - Scanning QR codes
   - Editing tokens
   - Navigating between tabs

2. Verify layouts in all orientations:
   - Outer display (portrait)
   - Inner display (portrait)
   - Inner display (landscape)

3. Test with different token counts:
   - Empty state
   - Single column (1-2 tokens)
   - Full grid (many tokens)

### Performance Considerations
- Layouts use `LazyVGrid` for efficient rendering
- Display detection is cached and only recalculated on orientation changes
- Transition animations are lightweight (opacity-based)
- No unnecessary view recreations during fold transitions

## Future Enhancements

### Potential Improvements
1. **Apple Pencil Support**: 
   - Manual token code entry with handwriting recognition
   - Sketched notes per token on inner display
   
2. **Split View Support**:
   - View token list + settings simultaneously on inner display
   - Drag-and-drop between groups
   
3. **Fold-Aware Features**:
   - "Tent mode" for secure code viewing (half-folded position)
   - Quick peek at codes on outer display without unlocking
   
4. **Display-Specific Settings**:
   - Different sort orders for inner vs outer
   - Customizable grid density per display

## Code Integration Summary

### New Files
- `DeviceCapabilities.swift` - Device detection and layout helpers
- `DisplayTransitionManager.swift` - Transition monitoring and management
- `IPHONE_DUO_OPTIMIZATIONS.md` - This documentation

### Modified Files
- `ContentView.swift` - Adaptive tab view style
- `TokensListView.swift` - Optimized grids and padding
- `GroupsView.swift` - Optimized grids and padding
- `TokenCardView.swift` - Display-aware sizing and spacing
- `QRScannerView.swift` - Dual-display scanning hints

### Key Modifiers Added
- `.deviceAdaptivePadding()` - Automatic display-appropriate padding
- `.responsiveToDisplayChanges()` - Smooth transition handling

## Backwards Compatibility

All optimizations are backwards compatible with existing iPhones:
- `DeviceCapabilities` gracefully detects non-Duo devices
- Layout modifications fall back to standard behavior
- No breaking changes to existing code
- Zero performance impact on older devices
