//
//  AppPreferences.swift
//  Shared
//
//  Created by Liubov Kaper  on 1/30/26.
//

import SwiftUI

/// Shared app preferences using AppStorage
/// Works across both iOS and macOS
enum AppPreferences {

    /// Color scheme preference
    enum ColorSchemePreference: String, CaseIterable, Identifiable {
        case light = "Light"
        case dark = "Dark"
        case colorful = "Colorful"

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .colorful: return .dark // Colorful uses dark base with cyan accents
            }
        }

        var icon: String {
            switch self {
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .colorful: return "sparkles"
            }
        }

        /// Whether this is the colorful theme (for applying accent colors)
        var isColorful: Bool { self == .colorful }

        /// The accent color for this theme
        var accentColor: Color {
            switch self {
            case .colorful: return .cyan
            default: return .accentColor
            }
        }
    }

    // Default values
    static let defaultColorScheme: ColorSchemePreference = .dark
    static let defaultFontSize: Double = 1.0
    static let minFontSize: Double = 0.8
    static let maxFontSize: Double = 1.5
}

/// View modifier to apply font size preference
struct FontSizeModifier: ViewModifier {
    let multiplier: Double
    let baseSize: Font

    // Base sizes for each font style (Apple HIG defaults)
    private var basePtSize: CGFloat {
        switch baseSize {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        default: return 17
        }
    }

    private var fontWeight: Font.Weight {
        switch baseSize {
        case .headline: return .semibold
        case .title, .title2, .title3: return .regular
        default: return .regular
        }
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: basePtSize * multiplier, weight: fontWeight))
    }
}

extension View {
    /// Apply font size preference
    func fontSizePreference(_ multiplier: Double, baseSize: Font = .body) -> some View {
        modifier(FontSizeModifier(multiplier: multiplier, baseSize: baseSize))
    }
}
