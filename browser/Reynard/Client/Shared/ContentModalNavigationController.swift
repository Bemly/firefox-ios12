//
//  ContentModalNavigationController.swift
//  Reynard
//
//  Created by Minh Ton on 30/7/26.
//

import UIKit

final class ContentModalNavigationController: UINavigationController {
    private let onDismissed: () -> Void
    
    init(rootViewController: UIViewController, onDismissed: @escaping () -> Void) {
        self.onDismissed = onDismissed
        super.init(rootViewController: rootViewController)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed else {
            return
        }
        onDismissed()
    }
}
