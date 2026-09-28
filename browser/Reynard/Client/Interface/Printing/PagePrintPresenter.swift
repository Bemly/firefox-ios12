//
//  PagePrintPresenter.swift
//  Reynard
//
//  Created by Minh Ton on 22/9/26.
//

import UIKit

enum PagePrintPresenter {
    static func present(
        pdfFileURL: URL,
        jobName: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard UIPrintInteractionController.isPrintingAvailable,
              let presenter = UIApplication.shared.topViewController() else {
            try? FileManager.default.removeItem(at: pdfFileURL)
            completion(.failure(PagePrintError.unavailable))
            return
        }
        
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = normalizedJobName(jobName)
        printController.printInfo = printInfo
        printController.printingItem = pdfFileURL
        
        let handler: UIPrintInteractionController.CompletionHandler = { controller, _, error in
            controller.printingItem = nil
            try? FileManager.default.removeItem(at: pdfFileURL)
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            let sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            printController.present(
                from: sourceRect,
                in: presenter.view,
                animated: true,
                completionHandler: handler
            )
        } else {
            printController.present(animated: true, completionHandler: handler)
        }
    }
    
    private static func normalizedJobName(_ jobName: String?) -> String {
        let trimmedName = jobName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? "Reynard" : trimmedName
    }
}

private enum PagePrintError: Error {
    case unavailable
}
