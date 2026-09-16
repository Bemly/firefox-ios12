//
//  LibraryTabBarStyle.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import UIKit

enum LibraryTabBarStyle {
    private enum UX {
        static let itemTitleFontSize: CGFloat = 10
    }
    
    static func apply(to tabBar: UITabBar) {
        tabBar.tintColor = .appLabel
        tabBar.unselectedItemTintColor = .appSecondaryLabel

        // UITabBarAppearance is iOS 13+. On iOS 12 use legacy bar styling. 见 AGENTS.md“iOS 12 兼容门禁清单”.
        guard #available(iOS 13.0, *) else {
            tabBar.barTintColor = .appSystemBackground
            tabBar.isTranslucent = false
            return
        }

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .appSystemBackground
        
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: UX.itemTitleFontSize, weight: .regular)]
        
        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.normal.iconColor = .appSecondaryLabel
            itemAppearance.normal.titleTextAttributes = titleAttributes.merging([.foregroundColor: UIColor.appSecondaryLabel]) { _, new in new }
            itemAppearance.selected.iconColor = .appLabel
            itemAppearance.selected.titleTextAttributes = titleAttributes.merging([.foregroundColor: UIColor.appLabel]) { _, new in new }
        }
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}
