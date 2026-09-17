//
//  DeveloperPreferencesViewController.swift
//  Reynard
//
//  Created by Minh Ton on 8/9/26.
//

import UIKit

final class DeveloperPreferencesViewController: SettingsTableViewController, UITextFieldDelegate, UITextViewDelegate {
    private enum UX {
        static let lineSpacing: CGFloat = 2
        static let portFieldWidth: CGFloat = 80
        static let portFieldHeight: CGFloat = 34
    }
    
    private enum Section: CaseIterable {
        case remoteDebugging
        case compositing
        case diagnostics

        var text: SettingsSectionText {
            switch self {
            case .remoteDebugging:
                return SettingsSectionText(headerTitle: NSLocalizedString("Remote Debugging", comment: ""))
            case .compositing:
                return SettingsSectionText(
                    headerTitle: NSLocalizedString("Compositing", tableName: "SettingsLocalizable", comment: ""),
                    footerTitle: NSLocalizedString("Renders web content with the GPU. Takes effect after restarting the app.", tableName: "SettingsLocalizable", comment: "")
                )
            case .diagnostics:
                return SettingsSectionText(headerTitle: NSLocalizedString("On-Device Diagnostics", comment: ""))
            }
        }
    }

    private enum Row {
        case remoteDebugging
        case remoteDebuggingPort
        case hardwareWebRender
        case diagnosticsJITBench
        case diagnosticsVideo720
        case diagnosticsVideo240
        case diagnosticsAnimation
        case diagnosticsAnimationCSS
        case diagnosticsWebGLAnim
    }

    private var isDebuggingEnabled = Prefs.DeveloperSettings.remoteDebuggingEnabled
    private var isHardwareWebRenderEnabled = Prefs.DeveloperSettings.hardwareWebRenderEnabled
    private let debugSwitch = UISwitch()
    private let hardwareWebRenderSwitch = UISwitch()
    private weak var footerTextView: UITextView?
    private let portTextField: UITextField = {
        let textField = UITextField(
            frame: CGRect(
                x: 0,
                y: 0,
                width: UX.portFieldWidth,
                height: UX.portFieldHeight
            )
        )
        textField.keyboardType = .numberPad
        textField.returnKeyType = .done
        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing
        return textField
    }()
    
    private func rows(for section: Section) -> [Row] {
        switch section {
        case .remoteDebugging:
            return isDebuggingEnabled
            ? [.remoteDebugging, .remoteDebuggingPort]
            : [.remoteDebugging]
        case .compositing:
            return [.hardwareWebRender]
        case .diagnostics:
            return [.diagnosticsJITBench, .diagnosticsVideo720, .diagnosticsVideo240, .diagnosticsAnimation, .diagnosticsAnimationCSS, .diagnosticsWebGLAnim]
        }
    }

    private func diagnosticsURL(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "html", subdirectory: "Diagnostics")
    }
    
    init() {
        super.init(style: .appGrouped)
        title = NSLocalizedString("Developer", comment: "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        debugSwitch.addTarget(
            self,
            action: #selector(debugSwitchDidChange),
            for: .valueChanged
        )
        hardwareWebRenderSwitch.addTarget(
            self,
            action: #selector(hardwareWebRenderSwitchDidChange),
            for: .valueChanged
        )
        portTextField.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isDebuggingEnabled = Prefs.DeveloperSettings.remoteDebuggingEnabled
        debugSwitch.isOn = isDebuggingEnabled
        isHardwareWebRenderEnabled = Prefs.DeveloperSettings.hardwareWebRenderEnabled
        hardwareWebRenderSwitch.isOn = isHardwareWebRenderEnabled
        portTextField.text = String(Prefs.DeveloperSettings.remoteDebuggingPort)
        tableView.reloadData()
    }
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }
        return rows(for: Section.allCases[section]).count
    }
    
    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else {
            return SettingsSectionText()
        }
        return Section.allCases[section].text
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard Section.allCases.indices.contains(section), isDebuggingEnabled else {
            return nil
        }
        
        let footerView = UITableViewHeaderFooterView(reuseIdentifier: nil)
        footerView.contentView.preservesSuperviewLayoutMargins = true
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .footnote)
        textView.textColor = .appSecondaryLabel
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [
            .foregroundColor: view.tintColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        textView.attributedText = instructions()
        textView.delegate = self
        footerTextView = textView
        footerView.contentView.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: footerView.contentView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: footerView.contentView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: footerView.contentView.layoutMarginsGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: footerView.contentView.layoutMarginsGuide.bottomAnchor),
        ])
        return footerView
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard Section.allCases.indices.contains(section), isDebuggingEnabled else {
            return .leastNormalMagnitude
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section) else {
            return UITableViewCell()
        }
        let sectionRows = rows(for: Section.allCases[indexPath.section])
        guard sectionRows.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }

        let cell = SettingsTableViewCell(style: .default, reuseIdentifier: nil)
        switch sectionRows[indexPath.row] {
        case .remoteDebugging:
            cell.textLabel?.text = NSLocalizedString("Remote Debugging via USB", comment: "")
            cell.accessoryView = debugSwitch
        case .remoteDebuggingPort:
            cell.textLabel?.text = NSLocalizedString("Remote Debugging Port", comment: "")
            cell.accessoryView = portTextField
            portTextField.text = String(Prefs.DeveloperSettings.remoteDebuggingPort)
        case .hardwareWebRender:
            cell.textLabel?.text = NSLocalizedString("Hardware WebRender", tableName: "SettingsLocalizable", comment: "")
            cell.accessoryView = hardwareWebRenderSwitch
            hardwareWebRenderSwitch.isOn = isHardwareWebRenderEnabled
        case .diagnosticsJITBench:
            cell.textLabel?.text = NSLocalizedString("JIT Bench (on-device)", comment: "")
            cell.textLabel?.textColor = view.tintColor
            cell.accessoryType = .disclosureIndicator
        case .diagnosticsVideo720:
            cell.textLabel?.text = NSLocalizedString("Video Test 720p (on-device)", comment: "")
            cell.textLabel?.textColor = view.tintColor
            cell.accessoryType = .disclosureIndicator
        case .diagnosticsVideo240:
            cell.textLabel?.text = NSLocalizedString("Video Drops 240p (on-device)", comment: "")
            cell.textLabel?.textColor = view.tintColor
            cell.accessoryType = .disclosureIndicator
        case .diagnosticsAnimation:
            cell.textLabel?.text = NSLocalizedString("Animation Composite (on-device)", comment: "")
            cell.textLabel?.textColor = view.tintColor
            cell.accessoryType = .disclosureIndicator
        case .diagnosticsAnimationCSS:
            cell.textLabel?.text = NSLocalizedString("Animation CSS (on-device)", tableName: "SettingsLocalizable", comment: "")
            cell.textLabel?.textColor = view.tintColor
            cell.accessoryType = .disclosureIndicator
        case .diagnosticsWebGLAnim:
            cell.textLabel?.text = NSLocalizedString("WebGL Animation (on-device)", tableName: "SettingsLocalizable", comment: "")
            cell.textLabel?.textColor = view.tintColor
            cell.accessoryType = .disclosureIndicator
        }
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else {
            return
        }
        let sectionRows = rows(for: Section.allCases[indexPath.section])
        guard sectionRows.indices.contains(indexPath.row) else {
            return
        }

        let diagnosticsName: String?
        switch sectionRows[indexPath.row] {
        case .remoteDebugging:
            return
        case .remoteDebuggingPort:
            portTextField.becomeFirstResponder()
            return
        case .hardwareWebRender:
            return
        case .diagnosticsJITBench:
            diagnosticsName = "bench"
        case .diagnosticsVideo720:
            diagnosticsName = "video"
        case .diagnosticsVideo240:
            diagnosticsName = "video240"
        case .diagnosticsAnimation:
            diagnosticsName = "anim"
        case .diagnosticsAnimationCSS:
            diagnosticsName = "cssanim"
        case .diagnosticsWebGLAnim:
            diagnosticsName = "webgl-anim"
        }
        if let name = diagnosticsName,
           let url = diagnosticsURL(name) {
            LibrarySharedUtils.openLinkInBrowser(url.absoluteString, from: self)
        }
    }
    
    // MARK: - Text Field Delegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        savePort()
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        savePort()
    }
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard string.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }),
              let currentText = textField.text,
              let textRange = Range(range, in: currentText) else {
            return false
        }
        
        let updatedText = currentText.replacingCharacters(in: textRange, with: string)
        guard updatedText.isEmpty else {
            return Int(updatedText).map { (1...65_535).contains($0) } ?? false
        }
        return true
    }
    
    // MARK: - Preference Updates
    
    @objc private func debugSwitchDidChange(_ sender: UISwitch) {
        Prefs.DeveloperSettings.remoteDebuggingEnabled = sender.isOn
        RemoteDebuggingSettingController.applyRemoteDebugging()
        
        if !sender.isOn {
            portTextField.resignFirstResponder()
        }
        isDebuggingEnabled = sender.isOn
        tableView.reloadData()
    }

    @objc private func hardwareWebRenderSwitchDidChange(_ sender: UISwitch) {
        // Backend is chosen at gfx init; takes effect after a cold restart.
        Prefs.DeveloperSettings.hardwareWebRenderEnabled = sender.isOn
        isHardwareWebRenderEnabled = sender.isOn
    }
    
    private func savePort() {
        guard let text = portTextField.text,
              let port = Int(text),
              (1...65_535).contains(port) else {
            portTextField.text = String(Prefs.DeveloperSettings.remoteDebuggingPort)
            return
        }
        
        Prefs.DeveloperSettings.remoteDebuggingPort = port
        RemoteDebuggingSettingController.applyRemoteDebugging()
        portTextField.text = String(port)
        footerTextView?.attributedText = instructions()
    }
    
    // MARK: - Footer
    
    private func instructions() -> NSAttributedString {
        let port = Prefs.DeveloperSettings.remoteDebuggingPort
        let urlString = "libimobiledevice.org"
        let linkText = urlString
            .map { String($0) }
            .joined(separator: "\u{2060}")
        let format = NSLocalizedString(
            """
            1. Install libimobiledevice by following the instructions at %@.
            2. Connect this device to your computer using USB, then tap Trust when prompted.
            3. In Terminal, run iproxy %d:%d and leave it running.
            4. In Firefox on your computer, open about:debugging and select Setup.
            5. Under Network Location, add localhost:%d, then select Connect.
            """,
            comment: "Remote debugging setup instructions; port placeholders"
        )
        let text = String(
            format: format,
            linkText,
            port,
            port,
            port
        )
        let font = UIFont.preferredFont(forTextStyle: .footnote)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = UX.lineSpacing
        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.appSecondaryLabel,
                .paragraphStyle: paragraphStyle,
            ]
        )
        let codeFont = UIFont.appMonospacedSystemFont(
            ofSize: font.pointSize,
            weight: .regular
        )
        let codeStrings = [
            String(format: "iproxy %d:%d", port, port),
            "about:debugging",
            String(format: "localhost:%d", port),
        ]
        for codeString in codeStrings {
            let codeRange = (text as NSString).range(of: codeString)
            attributedText.addAttribute(.font, value: codeFont, range: codeRange)
        }
        let linkRange = (text as NSString).range(of: linkText)
        attributedText.addAttribute(
            .link,
            value: URL(string: urlString)!,
            range: linkRange
        )
        return attributedText
    }
    
    func textView(
        _ textView: UITextView,
        shouldInteractWith url: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        LibrarySharedUtils.openLinkInBrowser(url.absoluteString, from: self)
        return false
    }
}
