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
            return false
        }
        
        return await withCheckedContinuation { continuation in
            var allowed = false
            let alert = PromptAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )
            alert.onDismissed = {
                continuation.resume(returning: allowed)
            }
            alert.setValue(
                NSAttributedString(
                    string: title,
                    attributes: [.font: UIFont.boldSystemFont(ofSize: 17)]
                ),
                forKey: "attributedTitle"
            )
            alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Allow", comment: ""), style: .default) { _ in
                allowed = true
            })
            presenter.present(alert, animated: true)
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
