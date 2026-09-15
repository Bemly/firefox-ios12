//
//  PromptAlertController.swift
//  Reynard
//
//  Created by Minh Ton on 3/8/26.
//

import UIKit

final class PromptAlertController: UIAlertController {
    var onDismissed: (() -> Void)?
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let handler = onDismissed
        onDismissed = nil
        DispatchQueue.main.async {
            handler?()
        }
    }
}
