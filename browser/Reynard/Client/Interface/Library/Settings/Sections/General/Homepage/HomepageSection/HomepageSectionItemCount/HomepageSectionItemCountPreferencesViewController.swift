//
//  HomepageSectionItemCountPreferencesViewController.swift
//  Reynard
//
//  Created by Minh Ton on 25/6/26.
//

import UIKit

final class HomepageSectionItemCountPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case values
    }
    
    private let values: [Int]
    private let selectValue: (Int) -> Void
    private var selectedValue: Int
    
    init(
        title: String,
        values: [Int],
        selectedValue: Int,
        selectValue: @escaping (Int) -> Void
    ) {
        self.values = values
        self.selectedValue = selectedValue
        self.selectValue = selectValue
        super.init(style: .appGrouped)
        self.title = title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }
        
        return values.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section),
              values.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        let value = values[indexPath.row]
        let cell = SettingsTableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "\(value)"
        cell.accessoryType = value == selectedValue ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section),
              values.indices.contains(indexPath.row) else {
            return
        }
        
        selectedValue = values[indexPath.row]
        selectValue(selectedValue)
        tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
    }
}
