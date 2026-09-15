//
//  AddWebsiteLanguageViewController.swift
//  Reynard
//
//  Created by Minh Ton on 11/7/26.
//

import UIKit

final class AddWebsiteLanguageViewController: SettingsTableViewController {
    private let languages: [WebsiteLanguage]
    private let onSelect: (WebsiteLanguage) -> Void
    private let searchController = UISearchController(searchResultsController: nil)
    private var query = ""
    
    private var displayedLanguages: [WebsiteLanguage] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return languages
        }
        
        return languages.filter { language in
            language.title.localizedCaseInsensitiveContains(trimmedQuery) ||
            language.code.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
    
    init(selectedCodes: [String], onSelect: @escaping (WebsiteLanguage) -> Void) {
        let selectedCodeSet = Set(WebsiteLanguageCatalog.sanitizedLanguageCodes(selectedCodes))
        self.languages = WebsiteLanguageCatalog.sortedSupportedLanguages.filter {
            !selectedCodeSet.contains($0.code)
        }
        self.onSelect = onSelect
        
        super.init(style: .insetGrouped)
        title = NSLocalizedString("Add Language", comment: "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSearch()
        tableView.register(AddWebsiteLanguageCell.self, forCellReuseIdentifier: AddWebsiteLanguageCell.reuseIdentifier)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(cancelButtonTapped)
        )
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedLanguages.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let displayedLanguages = self.displayedLanguages
        guard displayedLanguages.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: AddWebsiteLanguageCell.reuseIdentifier,
            for: indexPath
        ) as! AddWebsiteLanguageCell
        let language = displayedLanguages[indexPath.row]
        cell.display(language: language)
        cell.onAdd = { [weak self] in
            self?.select(language)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        let displayedLanguages = self.displayedLanguages
        guard displayedLanguages.indices.contains(indexPath.row) else {
            return
        }
        select(displayedLanguages[indexPath.row])
    }
    
    private func configureSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = NSLocalizedString("Search Languages", comment: "")
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    
    private func select(_ language: WebsiteLanguage) {
        dismiss(animated: true) { [onSelect] in
            onSelect(language)
        }
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
}

extension AddWebsiteLanguageViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        query = searchController.searchBar.text ?? ""
        tableView.reloadData()
    }
}
