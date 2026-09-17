//
//  NetworkProxyPreferencesViewController.swift
//  Reynard
//

import UIKit

final class NetworkProxyPreferencesViewController: SettingsTableViewController, UITextFieldDelegate {
    private enum UX {
        static let subtitleLineCount = 0
    }

    private enum Section: CaseIterable {
        case mode
        case custom
    }

    private enum CustomRow: CaseIterable {
        case host
        case port
    }

    private var displayedMode = Prefs.ProxyPreferences.mode

    private var displayedSections: [Section] {
        return displayedMode == .manual ? Section.allCases : [.mode]
    }

    init() {
        super.init(style: .appGrouped)
        title = NSLocalizedString("Network Proxy", tableName: "SettingsLocalizable", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(CustomNewTabURLCell.self, forCellReuseIdentifier: "NetworkProxyHostCell")
        tableView.register(CustomNewTabURLCell.self, forCellReuseIdentifier: "NetworkProxyPortCell")
    }

    // MARK: - Table Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return displayedSections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard displayedSections.indices.contains(section) else {
            return 0
        }

        switch displayedSections[section] {
        case .mode:
            return NetworkProxyMode.allCases.count
        case .custom:
            return CustomRow.allCases.count
        }
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        guard displayedSections.indices.contains(section) else {
            return SettingsSectionText()
        }

        switch displayedSections[section] {
        case .mode:
            return SettingsSectionText(
                headerTitle: NSLocalizedString("Network Proxy", tableName: "SettingsLocalizable", comment: ""),
                footerTitle: NSLocalizedString("Gecko uses its own network stack and does not read the iOS Wi-Fi proxy automatically. Applied to new connections.", tableName: "SettingsLocalizable", comment: "")
            )
        case .custom:
            return SettingsSectionText(
                headerTitle: NSLocalizedString("Custom Proxy", comment: ""),
                footerTitle: NSLocalizedString("HTTP, HTTPS and SOCKS share this host and port. Localhost is never proxied.", comment: "")
            )
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard displayedSections.indices.contains(indexPath.section) else {
            return UITableViewCell()
        }

        switch displayedSections[indexPath.section] {
        case .mode:
            guard NetworkProxyMode.allCases.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            return modeCell(for: NetworkProxyMode.allCases[indexPath.row])
        case .custom:
            guard CustomRow.allCases.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            return customCell(for: CustomRow.allCases[indexPath.row])
        }
    }

    // MARK: - Table Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard displayedSections.indices.contains(indexPath.section),
              displayedSections[indexPath.section] == .mode,
              NetworkProxyMode.allCases.indices.contains(indexPath.row) else {
            return
        }
        selectMode(NetworkProxyMode.allCases[indexPath.row])
    }

    // MARK: - Text Field Delegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        if textField.tag == 1 {
            commitHost(textField.text ?? "")
        } else {
            commitPort(textField.text ?? "")
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.tag == 1 {
            commitHost(textField.text ?? "")
        } else {
            commitPort(textField.text ?? "")
        }
    }

    // MARK: - Cells

    private func modeCell(for mode: NetworkProxyMode) -> UITableViewCell {
        let cell = SettingsTableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = NSLocalizedString(mode.title, comment: "Proxy mode")
        cell.detailTextLabel?.text = NSLocalizedString(mode.subtitle, comment: "Proxy mode")
        cell.detailTextLabel?.textColor = .appSecondaryLabel
        cell.detailTextLabel?.numberOfLines = UX.subtitleLineCount
        cell.accessoryType = mode == displayedMode ? .checkmark : .none
        return cell
    }

    private func customCell(for row: CustomRow) -> UITableViewCell {
        let identifier = row == .host ? "NetworkProxyHostCell" : "NetworkProxyPortCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? CustomNewTabURLCell else {
            return UITableViewCell()
        }
        cell.textField.delegate = self
        cell.textField.tag = row == .host ? 1 : 2
        cell.textField.autocorrectionType = .no
        cell.textField.autocapitalizationType = .none
        cell.textField.clearButtonMode = .whileEditing
        if row == .host {
            cell.textField.placeholder = NSLocalizedString("Host", comment: "")
            cell.textField.text = Prefs.ProxyPreferences.customHost
            cell.textField.keyboardType = .URL
        } else {
            cell.textField.placeholder = NSLocalizedString("Port", comment: "")
            cell.textField.text = String(Prefs.ProxyPreferences.customPort)
            cell.textField.keyboardType = .numberPad
        }
        cell.selectionStyle = .none
        return cell
    }

    // MARK: - Selection

    private func selectMode(_ mode: NetworkProxyMode) {
        guard displayedMode != mode else {
            return
        }

        view.endEditing(true)
        let showedCustomSection = displayedMode == .manual
        Prefs.ProxyPreferences.mode = mode
        NetworkProxyPolicyController.applyProxy()

        for indexPath in tableView.indexPathsForVisibleRows ?? [] where indexPath.section == 0 {
            guard NetworkProxyMode.allCases.indices.contains(indexPath.row) else {
                continue
            }
            tableView.cellForRow(at: indexPath)?.accessoryType =
                NetworkProxyMode.allCases[indexPath.row] == mode ? .checkmark : .none
        }

        let showsCustomSection = mode == .manual
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.tableView.performBatchUpdates {
                self.displayedMode = mode
                if showedCustomSection, !showsCustomSection {
                    self.tableView.deleteSections(IndexSet(integer: 1), with: .fade)
                } else if !showedCustomSection, showsCustomSection {
                    self.tableView.insertSections(IndexSet(integer: 1), with: .fade)
                }
            }
        }
    }

    private func commitHost(_ value: String) {
        let host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard host != Prefs.ProxyPreferences.customHost else {
            return
        }
        Prefs.ProxyPreferences.customHost = host
        NetworkProxyPolicyController.applyProxy()
    }

    private func commitPort(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmed), port > 0, port <= 65535,
              port != Prefs.ProxyPreferences.customPort else {
            return
        }
        Prefs.ProxyPreferences.customPort = port
        NetworkProxyPolicyController.applyProxy()
    }
}
