//
//  LanguagesPreferencesViewController.swift
//  Reynard
//
//  Created by Minh Ton on 11/7/26.
//

import UIKit

final class LanguagesPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case websiteLanguage
        
        var text: SettingsSectionText {
            switch self {
            case .websiteLanguage:
                return SettingsSectionText(
                    headerTitle: NSLocalizedString("Website Language", comment: ""),
                    footerTitle: NSLocalizedString("Some websites are available in multiple languages. Choose languages in the order you prefer.", comment: "")
                )
            }
        }
    }
    
    private enum Row {
        case language(String)
        case addLanguage
    }
    
    private var languageCodes: [String] = []
    
    private var rows: [Row] {
        return languageCodes.map(Row.language) + [.addLanguage]
    }
    
    private var canEditLanguages: Bool {
        return languageCodes.count > 1
    }
    
    init() {
        super.init(style: .insetGrouped)
        title = NSLocalizedString("Languages", comment: "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.allowsSelectionDuringEditing = true
        reloadLanguages()
        updateEditingMode(animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadLanguages()
        updateEditingMode(animated: false)
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }
        return rows.count
    }
    
    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else {
            return SettingsSectionText()
        }
        return Section.allCases[section].text
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = row(at: indexPath) else {
            return UITableViewCell()
        }
        
        switch row {
        case let .language(code):
            let cell = SettingsTableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = WebsiteLanguageCatalog.title(for: code)
            cell.selectionStyle = .none
            return cell
        case .addLanguage:
            let cell = SettingsTableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = NSLocalizedString("Add Language…", comment: "")
            cell.textLabel?.textColor = tableView.tintColor
            cell.imageView?.image = UIImage(named: "reynard.plus")?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = tableView.tintColor
            cell.shouldIndentWhileEditing = false
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard let row = row(at: indexPath) else {
            return
        }
        
        if case .addLanguage = row {
            presentAddLanguageViewController()
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard case .language = row(at: indexPath) else {
            return false
        }
        return canEditLanguages
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard case .language = row(at: indexPath) else {
            return false
        }
        return canEditLanguages
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return self.tableView(tableView, canEditRowAt: indexPath) ? .delete : .none
    }
    
    override func tableView(
        _ tableView: UITableView,
        targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        guard proposedDestinationIndexPath.section == sourceIndexPath.section else {
            return sourceIndexPath
        }
        
        if proposedDestinationIndexPath.row >= languageCodes.count {
            return IndexPath(row: languageCodes.count - 1, section: sourceIndexPath.section)
        }
        return proposedDestinationIndexPath
    }
    
    override func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        guard languageCodes.indices.contains(sourceIndexPath.row),
              languageCodes.indices.contains(destinationIndexPath.row) else {
            tableView.reloadData()
            return
        }
        
        let code = languageCodes.remove(at: sourceIndexPath.row)
        languageCodes.insert(code, at: destinationIndexPath.row)
        saveLanguages()
    }
    
    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete,
              canEditLanguages,
              languageCodes.indices.contains(indexPath.row) else {
            return
        }
        
        languageCodes.remove(at: indexPath.row)
        saveLanguages()
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateEditingMode(animated: true)
    }
    
    private func row(at indexPath: IndexPath) -> Row? {
        guard Section.allCases.indices.contains(indexPath.section),
              rows.indices.contains(indexPath.row) else {
            return nil
        }
        return rows[indexPath.row]
    }
    
    private func reloadLanguages() {
        languageCodes = Prefs.LanguageSettings.websiteLanguages
    }
    
    private func saveLanguages() {
        languageCodes = WebsiteLanguageCatalog.sanitizedLanguageCodes(languageCodes)
        Prefs.LanguageSettings.websiteLanguages = languageCodes
    }
    
    private func updateEditingMode(animated: Bool) {
        super.setEditing(canEditLanguages, animated: animated)
        tableView.setEditing(canEditLanguages, animated: animated)
    }
    
    private func presentAddLanguageViewController() {
        let viewController = AddWebsiteLanguageViewController(selectedCodes: languageCodes) { [weak self] language in
            self?.add(language)
        }
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }
    
    private func add(_ language: WebsiteLanguage) {
        guard !languageCodes.contains(language.code) else {
            return
        }
        
        languageCodes.insert(language.code, at: 0)
        saveLanguages()
        updateEditingMode(animated: true)
        tableView.reloadData()
    }
}
