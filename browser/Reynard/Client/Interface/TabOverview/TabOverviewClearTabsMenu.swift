//
//  TabOverviewClearTabsMenu.swift
//  Reynard
//
//  Created by Minh Ton on 14/8/26.
//

import UIKit

/// iOS 12 long-press fallback for the clear-tabs menu (no context-menu API).
/// Presents the same choices as `make(_:onClearTabs:onClearTabsOlderThan:)`
/// as an action sheet.
final class ClearTabsFallbackTarget: NSObject {
    private let tabCount: Int
    private let onClearTabs: () -> Void
    private let onClearTabsOlderThan: (TabOverviewClearTabsMenu.Age) -> Void

    init(
        tabCount: Int,
        onClearTabs: @escaping () -> Void,
        onClearTabsOlderThan: @escaping (TabOverviewClearTabsMenu.Age) -> Void
    ) {
        self.tabCount = tabCount
        self.onClearTabs = onClearTabs
        self.onClearTabsOlderThan = onClearTabsOlderThan
    }

    @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let view = recognizer.view else { return }
        var actions = [
            CompatMenuAction(
                title: String.localizedStringWithFormat(
                    NSLocalizedString("Close %d Tabs", comment: "Tab count"),
                    tabCount
                ),
                style: .destructive,
                handler: onClearTabs
            )
        ]
        for age in TabOverviewClearTabsMenu.Age.allCases {
            actions.append(CompatMenuAction(title: age.title) { [onClearTabsOlderThan] in
                onClearTabsOlderThan(age)
            })
        }
        view.compatPresentMenu(actions)
    }
}

enum TabOverviewClearTabsMenu {
    enum Age: Int, CaseIterable {
        case day
        case week
        case month
        
        var title: String {
            switch self {
            case .day:
                return NSLocalizedString("Older Than 1 Day", comment: "Tab age")
            case .week:
                return NSLocalizedString("Older Than 1 Week", comment: "Tab age")
            case .month:
                return NSLocalizedString("Older Than 1 Month", comment: "Tab age")
            }
        }
        
        func cutoffDate(from now: Date = Date(), calendar: Calendar = .current) -> Date? {
            switch self {
            case .day:
                return now.addingTimeInterval(-86_400)
            case .week:
                return now.addingTimeInterval(-604_800)
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: now)
            }
        }
    }
    
    @available(iOS 13.0, *)
    static func make(
        tabCount: Int,
        onClearTabs: @escaping () -> Void,
        onClearTabsOlderThan: @escaping (Age) -> Void
    ) -> UIMenu {
        let ageActions = Age.allCases.map { age in
            UIAction(title: age.title) { _ in
                onClearTabsOlderThan(age)
            }
        }
        let closeOldTabsMenu = UIMenu(
            title: NSLocalizedString("Close Old Tabs...", comment: "Tab age menu"),
            children: ageActions
        )
        return UIMenu(title: "", children: [
            UIAction(
                title: String.localizedStringWithFormat(NSLocalizedString("Close %d Tabs", comment: "Tab count"), tabCount),
                attributes: .destructive
            ) { _ in
                onClearTabs()
            },
            closeOldTabsMenu,
        ])
    }
}
