//
//  PagePrintActivity.swift
//  Reynard
//
//  Created by Minh Ton on 22/9/26.
//

import GeckoView
import UIKit

final class PagePrintActivity: UIActivity {
    private let session: GeckoSession
    private let jobName: String?
    
    init(session: GeckoSession, jobName: String?) {
        self.session = session
        self.jobName = jobName
        super.init()
    }
    
    override class var activityCategory: UIActivity.Category { .action }
    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("moe.bemly.reynard.PagePrintActivity")
    }
    override var activityTitle: String? { NSLocalizedString("Print", comment: "") }
    override var activityImage: UIImage? { UIImage(named: "reynard.printer") }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return UIPrintInteractionController.isPrintingAvailable
    }
    
    override func perform() {
        PagePrintPreparationAlert.prepare({ [session] operationCompletion in
            session.printToPDF(completion: operationCompletion)
        }) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let pdfFileURL):
                PagePrintPresenter.present(pdfFileURL: pdfFileURL, jobName: self.jobName) { [weak self] result in
                    if case .success = result {
                        self?.activityDidFinish(true)
                    } else {
                        self?.activityDidFinish(false)
                    }
                }
            case .failure:
                self.activityDidFinish(false)
            }
        }
    }
}
