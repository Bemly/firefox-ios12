//
//  UICompat.swift
//  Reynard
//
//  iOS 12 compatibility shims for UIKit APIs introduced in iOS 13+.
//  Each accessor returns the native semantic value on iOS 13 and later,
//  and a fixed light-appearance fallback on iOS 12 (which has no dark mode).
//

import UIKit

extension UIColor {
    static var appLabel: UIColor {
        if #available(iOS 13.0, *) { return .label }
        return .black
    }
    static var appSecondaryLabel: UIColor {
        if #available(iOS 13.0, *) { return .secondaryLabel }
        return UIColor(white: 0.24, alpha: 0.6)
    }
    static var appTertiaryLabel: UIColor {
        if #available(iOS 13.0, *) { return .tertiaryLabel }
        return UIColor(white: 0.24, alpha: 0.3)
    }
    static var appSystemBackground: UIColor {
        if #available(iOS 13.0, *) { return .systemBackground }
        return .white
    }
    static var appSecondarySystemBackground: UIColor {
        if #available(iOS 13.0, *) { return .secondarySystemBackground }
        return UIColor(white: 0.95, alpha: 1)
    }
    static var appTertiarySystemBackground: UIColor {
        if #available(iOS 13.0, *) { return .tertiarySystemBackground }
        return .white
    }
    static var appSystemGroupedBackground: UIColor {
        if #available(iOS 13.0, *) { return .systemGroupedBackground }
        return UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    }
    static var appSecondarySystemGroupedBackground: UIColor {
        if #available(iOS 13.0, *) { return .secondarySystemGroupedBackground }
        return .white
    }
    static var appSystemFill: UIColor {
        if #available(iOS 13.0, *) { return .systemFill }
        return UIColor(white: 0.47, alpha: 0.2)
    }
    static var appSecondarySystemFill: UIColor {
        if #available(iOS 13.0, *) { return .secondarySystemFill }
        return UIColor(white: 0.47, alpha: 0.16)
    }
    static var appTertiarySystemFill: UIColor {
        if #available(iOS 13.0, *) { return .tertiarySystemFill }
        return UIColor(white: 0.46, alpha: 0.12)
    }
    static var appQuaternarySystemFill: UIColor {
        if #available(iOS 13.0, *) { return .quaternarySystemFill }
        return UIColor(white: 0.45, alpha: 0.08)
    }
    static var appSeparator: UIColor {
        if #available(iOS 13.0, *) { return .separator }
        return UIColor(white: 0.24, alpha: 0.29)
    }
    static var appLink: UIColor {
        if #available(iOS 13.0, *) { return .link }
        return UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
    }
    static var appPlaceholderText: UIColor {
        if #available(iOS 13.0, *) { return .placeholderText }
        return UIColor(white: 0.24, alpha: 0.3)
    }
    static var appSystemGray4: UIColor {
        if #available(iOS 13.0, *) { return .systemGray4 }
        return UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1)
    }
    static var appSystemGray5: UIColor {
        if #available(iOS 13.0, *) { return .systemGray5 }
        return UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1)
    }
    static var appSystemGray6: UIColor {
        if #available(iOS 13.0, *) { return .systemGray6 }
        return UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    }
    /// Backport of `UIColor.init(dynamicProvider:)` (iOS 13+). On iOS 12 the
    /// provider is evaluated once against an empty (light) trait collection.
    static func appDynamic(_ provider: @escaping (UITraitCollection) -> UIColor) -> UIColor {
        if #available(iOS 13.0, *) { return UIColor(dynamicProvider: provider) }
        return provider(UITraitCollection(traitsFrom: []))
    }
    /// Backport of `resolvedColor(with:)` (iOS 13+). Colors are static on iOS 12.
    func appResolved(with traits: UITraitCollection) -> UIColor {
        if #available(iOS 13.0, *) { return resolvedColor(with: traits) }
        return self
    }
}

extension UIStatusBarStyle {
    /// `.darkContent` on iOS 13+; `.default` (dark text) on iOS 12.
    static var compatDarkContent: UIStatusBarStyle {
        if #available(iOS 13.0, *) { return .darkContent }
        return .default
    }
}

extension UIFont {
    /// Backport of `monospacedSystemFont(ofSize:weight:)` (iOS 13+).
    /// Menlo ships on all iOS versions; falls back to the system font.
    static func appMonospacedSystemFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if #available(iOS 13.0, *) { return .monospacedSystemFont(ofSize: size, weight: weight) }
        return UIFont(name: "Menlo-Regular", size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}

extension UITableView.Style {    /// `.insetGrouped` on iOS 13+, falling back to `.grouped` on iOS 12.
    static var appGrouped: UITableView.Style {
        if #available(iOS 13.0, *) { return .insetGrouped }
        return .grouped
    }
}

extension CALayer {
    /// Applies the continuous (squircle) corner curve on iOS 13+; no-op on iOS 12.
    func applyContinuousCornerCurve() {
        if #available(iOS 13.0, *) {
            cornerCurve = .continuous
        }
    }
}

extension UISearchBar {
    /// The inner search text field on iOS 13+, or the search bar itself on iOS 12
    /// (used only for layout alignment). 见 AGENTS.md“iOS 12 兼容门禁清单”.
    var compatAlignmentView: UIView {
        if #available(iOS 13.0, *) { return searchTextField }
        return self
    }
}

extension UIBlurEffect.Style {
    /// `.systemChromeMaterial` on iOS 13+, `.regular` on iOS 12.
    static var appChromeMaterial: UIBlurEffect.Style {
        if #available(iOS 13.0, *) { return .systemChromeMaterial }
        return .regular
    }
    /// `.systemMaterial` on iOS 13+, `.regular` on iOS 12.
    static var appMaterial: UIBlurEffect.Style {
        if #available(iOS 13.0, *) { return .systemMaterial }
        return .regular
    }
}

extension UIWindow {
    /// Scene activation state on iOS 13+; always true on iOS 12 (no scenes).
    var compatIsForegroundActive: Bool {
        if #available(iOS 13.0, *) { return windowScene?.activationState == .foregroundActive }
        return true
    }
}

extension UIView {
    /// Scene interface orientation on iOS 13+; nil on iOS 12 (no scenes).
    var compatInterfaceOrientation: UIInterfaceOrientation? {
        if #available(iOS 13.0, *) { return window?.windowScene?.interfaceOrientation }
        return nil
    }
}
