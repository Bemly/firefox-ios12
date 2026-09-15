//
//  ClearDataTimeframe.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import UIKit

enum ClearDataTimeframe: Int, CaseIterable {
    case lastHour
    case today
    case todayAndYesterday
    case allTime
    
    func cutoffDate(from now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .lastHour:
            return now.addingTimeInterval(-3_600)
        case .today:
            return calendar.startOfDay(for: now)
        case .todayAndYesterday:
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        case .allTime:
            return nil
        }
    }
    
    static func configureCell(
        _ cell: UITableViewCell,
        at indexPath: IndexPath,
        selectedTimeframe: ClearDataTimeframe,
        allTimeTitle: String = NSLocalizedString("All History", comment: "")
    ) {
        let option = allCases[indexPath.row]
        switch option {
        case .lastHour:
            cell.textLabel?.text = NSLocalizedString("Last Hour", comment: "")
        case .today:
            cell.textLabel?.text = NSLocalizedString("Today", comment: "")
        case .todayAndYesterday:
            cell.textLabel?.text = NSLocalizedString("Today and Yesterday", comment: "")
        case .allTime:
            cell.textLabel?.text = allTimeTitle
        }
        cell.accessoryView = nil
        cell.accessoryType = option == selectedTimeframe ? .checkmark : .none
        cell.selectionStyle = .default
    }
}
