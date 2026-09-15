//
//  OpenLinksInNewTabsPreferencesViewController.swift
//  Reynard
//
//  Created by Minh Ton on 9/9/26.
//

import UIKit

final class OpenLinksInNewTabsPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case behavior
        
        var text: SettingsSectionText {
            return SettingsSectionText()
        }
    }
    
    init() {
        super.init(style: .insetGrouped)
        title = NSLocalizedString("Open Links in New Tabs", comment: "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }
        return OpenLinksInNewTabsBehavior.allCases.count
    }
    
    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else {
            return SettingsSectionText()
        }
        return Section.allCases[section].text
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section),
              OpenLinksInNewTabsBehavior.allCases.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        let behavior = OpenLinksInNewTabsBehavior.allCases[indexPath.row]
        let cell = SettingsTableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = behavior.title
        cell.accessoryType = Prefs.BrowsingSettings.openLinksInNewTabsBehavior == behavior ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section),
              OpenLinksInNewTabsBehavior.allCases.indices.contains(indexPath.row) else {
            return
        }
        
        Prefs.BrowsingSettings.openLinksInNewTabsBehavior = OpenLinksInNewTabsBehavior.allCases[indexPath.row]
        tableView.reloadData()
    }
}
