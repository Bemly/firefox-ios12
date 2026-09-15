//
//  SettingsTableViewController.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import UIKit

class SettingsTableViewController: UITableViewController {
    private enum UX {
        static let sectionHeaderTopPadding: CGFloat = 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // iOS 12: these settings screens are pushed onto the sidebar's nav stack,
        // where the old embedded UISplitViewController doesn't propagate the
        // nav-bar safe-area inset -- keep table content below the title bar.
        if #unavailable(iOS 13.0) {
            edgesForExtendedLayout = []
        }
        configureTableView()
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionText(for: section).headerTitle
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sectionText(for: section).footerTitle
    }
    
    func sectionText(for section: Int) -> SettingsSectionText {
        return SettingsSectionText()
    }
    
    private func configureTableView() {
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .interactive
        if #available(iOS 14.0, *) {
            tableView.selectionFollowsFocus = false
        }
        
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = UX.sectionHeaderTopPadding
        }
    }
}
