//
//  ExperimentalFeaturesViewController.swift
//  Reynard
//
//  Created by Minh Ton on 19/7/26.
//

import UIKit

final class ExperimentalFeaturesViewController: SettingsTableViewController {
    private enum UX {
        static let restartDelay = 1
    }
    
    private enum Section: CaseIterable {
        case features
        
        var text: SettingsSectionText {
            return SettingsSectionText()
        }
    }
    
    private enum Row: CaseIterable {
        case videoPictureInPicture
    }
    
    private let videoPictureInPictureSwitch = UISwitch()
    
    init() {
        super.init(style: .insetGrouped)
        title = "Experimental Features"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSwitch()
        refreshDisplayedState()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDisplayedState()
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }
        
        switch Section.allCases[section] {
        case .features:
            return Row.allCases.count
        }
    }
    
    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else {
            return SettingsSectionText()
        }
        return Section.allCases[section].text
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section),
              Row.allCases.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        switch Row.allCases[indexPath.row] {
        case .videoPictureInPicture:
            return switchCell(
                title: "Video Picture-in-Picture",
                accessoryView: videoPictureInPictureSwitch
            )
        }
    }
    
    private func configureSwitch() {
        videoPictureInPictureSwitch.addTarget(self, action: #selector(videoPictureInPictureSwitchDidChange(_:)), for: .valueChanged)
    }
    
    private func refreshDisplayedState() {
        videoPictureInPictureSwitch.isOn = Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled
    }
    
    @objc private func videoPictureInPictureSwitchDidChange(_ sender: UISwitch) {
        Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled = sender.isOn
        showRestartAlert()
    }
    
    private func showRestartAlert() {
        let alert = UIAlertController(
            title: "Restart Required",
            message: "The app will now close for the experimental setting to take effect.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .seconds(UX.restartDelay)
            ) {
                exit(EXIT_SUCCESS)
            }
        })
        present(alert, animated: true)
    }
    
    private func switchCell(title: String, accessoryView: UISwitch) -> UITableViewCell {
        let cell = SettingsTableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.textLabel?.text = title
        cell.accessoryView = accessoryView
        return cell
    }
}
