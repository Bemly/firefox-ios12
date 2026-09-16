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
        // Don't use super.init(rootViewController:): UIKit's implementation
        // re-dispatches into initWithNibName:bundle:, whose @objc thunk traps
        // ("use of unimplemented initializer") because this class defines its
        // own designated init and no longer inherits that one.
        super.init(nibName: nil, bundle: nil)
        viewControllers = [rootViewController]
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
