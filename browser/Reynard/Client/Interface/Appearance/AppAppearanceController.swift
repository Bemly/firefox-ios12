//
//  AppAppearanceController.swift
//  Reynard
//
//  Created by Minh Ton on 22/6/26.
//

import UIKit

enum AppAppearanceController {
    static func apply(_ appearance: AppAppearance) {
        // iOS 12 has no dark mode / overrideUserInterfaceStyle; no-op. 见 AGENTS.md“iOS 12 兼容门禁清单”.
        guard #available(iOS 13.0, *) else {
            return
        }

        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { window in
                window.overrideUserInterfaceStyle = userInterfaceStyle(for: appearance)
            }
    }

    @available(iOS 13.0, *)
    static func userInterfaceStyle(for appearance: AppAppearance) -> UIUserInterfaceStyle {
        switch appearance {
        case .system:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
