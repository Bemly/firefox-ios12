//
//  SettingsTableViewCell.swift
//  Reynard
//
//  Created by Minh Ton on 18/8/26.
//

import UIKit

final class SettingsTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel?.numberOfLines = 0
        textLabel?.lineBreakMode = .byWordWrapping
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var canBecomeFirstResponder: Bool {
        detailTextLabel?.isUserInteractionEnabled == true
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        canBecomeFirstResponder && action == #selector(copy(_:)) && detailTextLabel?.text?.isEmpty == false
    }
    
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = detailTextLabel?.text
    }
    
    func configureDetailTextCopying() {
        detailTextLabel?.isUserInteractionEnabled = true
        detailTextLabel?.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(handleDetailTextLongPress(_:)))
        )
    }
    
    @objc private func handleDetailTextLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began,
              let sourceView = gestureRecognizer.view,
              becomeFirstResponder() else {
            return
        }
        
        if #available(iOS 13.0, *) {
            UIMenuController.shared.showMenu(from: sourceView, rect: sourceView.bounds)
        } else {
            UIMenuController.shared.setTargetRect(sourceView.bounds, in: sourceView)
            UIMenuController.shared.setMenuVisible(true, animated: true)
        }
    }
}
