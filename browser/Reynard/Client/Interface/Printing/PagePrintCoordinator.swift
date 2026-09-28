//
//  PagePrintCoordinator.swift
//  Reynard
//
//  Created by Minh Ton on 22/9/26.
//

import GeckoView

final class PagePrintCoordinator: PrintDelegate {
    private let jobName: (GeckoSession) -> String?
    
    init(jobName: @escaping (GeckoSession) -> String?) {
        self.jobName = jobName
    }
    
    func onPrint(
        session: GeckoSession,
        browsingContextId: Int64?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        PagePrintPreparationAlert.prepare({ operationCompletion in
            session.printToPDF(browsingContextId: browsingContextId, completion: operationCompletion)
        }) { [jobName] result in
            switch result {
            case .success(let pdfFileURL):
                PagePrintPresenter.present(
                    pdfFileURL: pdfFileURL,
                    jobName: jobName(session),
                    completion: completion
                )
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
