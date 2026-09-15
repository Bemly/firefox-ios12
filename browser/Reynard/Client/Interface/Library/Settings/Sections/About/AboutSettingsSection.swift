//
//  AboutSettingsSection.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import GeckoView
import UIKit

final class AboutSettingsSection {
    enum Row: CaseIterable {
        case experimentalFeatures
        case appVersion
        case engineVersion
        case sourceCode
        case supportProject
        case githubProfile
    }
    
    private var showsExperimentalFeatures = false
    
    private var displayedRows: [Row] {
        return Row.allCases.filter {
            showsExperimentalFeatures || $0 != .experimentalFeatures
        }
    }
    
    var rowCount: Int {
        return displayedRows.count
    }
    
    func revealExperimentalFeatures() -> Bool {
        guard !showsExperimentalFeatures else {
            return false
        }
        showsExperimentalFeatures = true
        return true
    }
    
    func isAppVersionRow(at index: Int) -> Bool {
        return displayedRows.indices.contains(index) &&
        displayedRows[index] == .appVersion
    }
    
    func cell(at index: Int) -> UITableViewCell {
        guard displayedRows.indices.contains(index) else {
            return UITableViewCell()
        }
        
        switch displayedRows[index] {
        case .experimentalFeatures:
            return SettingsViewUtils.disclosureCell(title: "Experimental Features")
        case .appVersion:
            let info = Bundle.main.infoDictionary
            let version = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let build = info?["CFBundleVersion"] as? String ?? "Unknown"
            return valueCell(title: NSLocalizedString("Reynard Browser", comment: ""), value: "\(version) (\(build))")
        case .engineVersion:
            return valueCell(title: NSLocalizedString("Engine Version", comment: ""), value: GeckoRuntime.version)
        case .sourceCode:
            return linkCell(title: NSLocalizedString("View Source Code", comment: ""))
        case .supportProject:
            return linkCell(title: NSLocalizedString("Support The Project", comment: ""))
        case .githubProfile:
            return linkCell(title: NSLocalizedString("GitHub - @minh-ton", comment: ""))
        }
    }
    
    func selectRow(at index: Int, from viewController: UIViewController) {
        guard displayedRows.indices.contains(index) else {
            return
        }
        
        let row = displayedRows[index]
        if row == .experimentalFeatures {
            viewController.navigationController?.pushViewController(
                ExperimentalFeaturesViewController(),
                animated: true
            )
            return
        }
        
        if let url = url(for: row) {
            LibrarySharedUtils.openLinkInBrowser(url.absoluteString, from: viewController)
        }
    }
    
    private func url(for row: Row) -> URL? {
        switch row {
        case .sourceCode:
            return URL(string: "https://github.com/minh-ton/reynard-browser")
        case .supportProject:
            return URL(string: "https://buymeacoffee.com/hnimnot")
        case .githubProfile:
            return URL(string: "https://github.com/minh-ton")
        case .experimentalFeatures, .appVersion, .engineVersion:
            return nil
        }
    }
    
    private func valueCell(title: String, value: String) -> UITableViewCell {
        let cell = SettingsTableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = value
        cell.detailTextLabel?.textColor = .appSecondaryLabel
        cell.selectionStyle = .none
        cell.accessoryType = .none
        return cell
    }
    
    private func linkCell(title: String) -> UITableViewCell {
        let cell = SettingsTableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = title
        cell.textLabel?.textColor = .systemBlue
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}
