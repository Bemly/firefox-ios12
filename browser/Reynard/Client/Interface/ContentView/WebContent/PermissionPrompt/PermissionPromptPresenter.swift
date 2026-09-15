//
//  PermissionPromptPresenter.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import GeckoView
import UIKit

struct PermissionPromptPresenter: PermissionPromptPresenting {
    
    func request(
        title: String,
        message: String?,
        cancelTitle: String,
        for session: GeckoSession,
        completion: @escaping (Bool) -> Void
    ) {
        guard let presenter = UIApplication.shared.topViewController() else {
            completion(false)
            return
        }

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.setValue(
            NSAttributedString(
                string: title,
                attributes: [.font: UIFont.boldSystemFont(ofSize: 17)]
            ),
            forKey: "attributedTitle"
        )
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            completion(false)
        })
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
            completion(true)
        })
        presenter.present(alert, animated: true)
    }
}
