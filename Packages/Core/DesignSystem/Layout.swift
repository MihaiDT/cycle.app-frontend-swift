import SwiftUI

// MARK: - Layout Constants

/// Global layout constants for consistent spacing across all screens
public enum AppLayout {
    // MARK: - Screen Margins

    /// **Standard screen-edge gutter** used by every feature surface
    /// (Today tab, Cycle Stats, Cycle Journey, etc.). Matches the
    /// Cycle Stats card list's `contentInsets` so every screen in the
    /// app feels aligned on the same vertical column. Tight 14pt — the
    /// point of this app is editorial content; wider gutters make the
    /// content feel postage-stampy on a phone.
    public static let screenHorizontal: CGFloat = 14

    /// Horizontal padding for content (left/right) — legacy / editorial.
    /// Used by onboarding screens where a wider margin is intentional.
    /// New code should reach for `screenHorizontal` by default.
    public static let horizontalPadding: CGFloat = 32

    /// Small horizontal padding for tighter layouts
    public static let horizontalPaddingSmall: CGFloat = 24

    /// Large horizontal padding for extra breathing room
    public static let horizontalPaddingLarge: CGFloat = 48

    // MARK: - Safe Area Offsets

    /// Top offset from safe area (for main content start)
    public static let topOffset: CGFloat = 40

    /// Bottom offset from safe area (for buttons, actions)
    public static let bottomOffset: CGFloat = 24

    // MARK: - Spacing

    /// Extra small spacing (4pt)
    public static let spacingXS: CGFloat = 4

    /// Small spacing (8pt)
    public static let spacingS: CGFloat = 8

    /// Medium spacing (16pt)
    public static let spacingM: CGFloat = 16

    /// Large spacing (24pt)
    public static let spacingL: CGFloat = 24

    /// Extra large spacing (32pt)
    public static let spacingXL: CGFloat = 32

    /// XXL spacing (48pt)
    public static let spacingXXL: CGFloat = 48

    // MARK: - Component Sizes

    /// Standard button height
    public static let buttonHeight: CGFloat = 55

    /// Standard button width
    public static let buttonWidth: CGFloat = 203

    /// Icon container size (for shields, illustrations)
    public static let iconLarge: CGFloat = 237

    /// Medium icon size
    public static let iconMedium: CGFloat = 140

    /// Checkbox/small icon size
    public static let iconSmall: CGFloat = 24

    /// Minimum tap target (Apple HIG)
    public static let minTapTarget: CGFloat = 44

    // MARK: - Corner Radius

    /// Small corner radius (8pt)
    public static let cornerRadiusS: CGFloat = 8

    /// Medium corner radius (16pt)
    public static let cornerRadiusM: CGFloat = 16

    /// Large corner radius (24pt)
    public static let cornerRadiusL: CGFloat = 24

    /// XL corner radius (30pt) - for cards
    public static let cornerRadiusXL: CGFloat = 30

    /// Capsule/pill shape
    public static let cornerRadiusCapsule: CGFloat = 100
}

// MARK: - View Extensions

extension View {
    /// Apply standard horizontal padding
    public func horizontalPadding() -> some View {
        padding(.horizontal, AppLayout.horizontalPadding)
    }

    /// Apply standard screen margins (horizontal + safe areas considered)
    public func screenPadding() -> some View {
        padding(.horizontal, AppLayout.horizontalPadding)
    }

    /// Standard bottom padding for action buttons
    public func bottomActionPadding(_ geometry: GeometryProxy) -> some View {
        padding(.bottom, geometry.safeAreaInsets.bottom + AppLayout.bottomOffset)
    }
}

// MARK: - Spacing View

/// Convenience view for consistent vertical spacing
public struct VerticalSpace: View {
    private let height: CGFloat

    public init(_ height: CGFloat) {
        self.height = height
    }

    public var body: some View {
        Spacer()
            .frame(height: height)
    }
}

// MARK: - Common Spacing Shortcuts

extension VerticalSpace {
    public static var xs: VerticalSpace { VerticalSpace(AppLayout.spacingXS) }
    public static var s: VerticalSpace { VerticalSpace(AppLayout.spacingS) }
    public static var m: VerticalSpace { VerticalSpace(AppLayout.spacingM) }
    public static var l: VerticalSpace { VerticalSpace(AppLayout.spacingL) }
    public static var xl: VerticalSpace { VerticalSpace(AppLayout.spacingXL) }
    public static var xxl: VerticalSpace { VerticalSpace(AppLayout.spacingXXL) }
}
