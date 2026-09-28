//
//  PagePrintPreparationAlert.swift
//  Reynard
//
//  Created by Minh Ton on 22/9/26.
//

import UIKit

// NOTE (iOS 12 port): async/await + Task cancellation replaced with
// completion handlers and a generation flag (no Swift Concurrency on iOS 12).
enum PagePrintPreparationAlert {
    typealias Operation = (@escaping (Result<URL, Error>) -> Void) -> Void
    
    static func prepare(
        _ operation: @escaping Operation,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let presenter = UIApplication.shared.topViewController() else {
            completion(.failure(PagePrintPreparationError.unavailable))
            return
        }
        PagePrintPreparation(operation: operation, completion: completion).run(from: presenter)
    }
}

private final class PagePrintPreparation {
    private enum UX {
        static let activityIndicatorSpacing: CGFloat = 8
    }
    
    private let operation: PagePrintPreparationAlert.Operation
    private let alert = UIAlertController(
        title: nil,
        message: NSLocalizedString("Preparing Page for Printing…", comment: ""),
        preferredStyle: .alert
    )
    private var completion: ((Result<URL, Error>) -> Void)?
    private var isCancelled = false
    
    init(
        operation: @escaping PagePrintPreparationAlert.Operation,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        self.operation = operation
        self.completion = completion
        // The pending present/operation callbacks keep self alive while the
        // alert is up, so the action only needs a weak reference.
        alert.addAction(
            UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { [weak self] _ in
                self?.cancel()
            }
        )
    }
    
    func run(from presenter: UIViewController) {
        presenter.present(alert, animated: true) {
            self.installActivityIndicator()
            self.prepare()
        }
    }
    
    private func prepare() {
        operation { result in
            guard !self.isCancelled else {
                if case .success(let fileURL) = result {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                return
            }
            self.dismissAlert {
                self.resume(with: result)
            }
        }
    }
    
    private func cancel() {
        isCancelled = true
        guard let completion else {
            return
        }
        self.completion = nil
        completion(.failure(PagePrintPreparationError.cancelled))
    }
    
    private func installActivityIndicator() {
        guard let messageText = alert.message,
              let messageLabel = alert.view.firstDescendantLabel(withText: messageText) else {
            return
        }
        
        let activityIndicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            activityIndicator = UIActivityIndicatorView(style: .medium)
        } else {
            activityIndicator = UIActivityIndicatorView(style: .gray)
        }
        activityIndicator.startAnimating()
        
        let statusLabel = UILabel()
        statusLabel.font = messageLabel.font
        statusLabel.text = messageText
        statusLabel.textColor = messageLabel.textColor
        
        let contentView = UIStackView(arrangedSubviews: [activityIndicator, statusLabel])
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .horizontal
        contentView.alignment = .center
        contentView.spacing = UX.activityIndicatorSpacing
        alert.view.addSubview(contentView)
        messageLabel.textColor = .clear
        messageLabel.isAccessibilityElement = false
        
        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: messageLabel.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: messageLabel.centerYAnchor),
        ])
    }
    
    private func dismissAlert(completion: @escaping () -> Void) {
        guard alert.presentingViewController != nil else {
            completion()
            return
        }
        alert.dismiss(animated: true, completion: completion)
    }
    
    private func resume(with result: Result<URL, Error>) {
        guard let completion else {
            if case .success(let fileURL) = result {
                try? FileManager.default.removeItem(at: fileURL)
            }
            return
        }
        self.completion = nil
        completion(result)
    }
}

private enum PagePrintPreparationError: Error {
    case unavailable
    case cancelled
}
