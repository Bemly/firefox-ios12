//
//  FindInPageTextField+KeyCommands.swift
//  Reynard
//
//  Created by Minh Ton on 15/8/26.
//

import UIKit

final class FindInPageTextField: UITextField {
    var onDismiss: (() -> Void)?
    
    private lazy var dismissCommand: UIKeyCommand = {
        let command = UIKeyCommand(
            input: UIKeyCommand.inputEscape,
            modifierFlags: [],
            action: #selector(dismissFindInPage(_:))
        )
        if #available(iOS 15.0, *) {
            command.wantsPriorityOverSystemBehavior = true
        }
        return command
    }()
    
    override var keyCommands: [UIKeyCommand]? {
        return (super.keyCommands ?? []) + [dismissCommand]
    }
    
    @objc private func dismissFindInPage(_ sender: UIKeyCommand) {
        onDismiss?()
    }
}
