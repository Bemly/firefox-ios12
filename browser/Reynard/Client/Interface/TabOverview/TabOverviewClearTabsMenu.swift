//
//  TabOverviewClearTabsMenu.swift
//  Reynard
//
//  Created by Minh Ton on 14/8/26.
//

import UIKit

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
