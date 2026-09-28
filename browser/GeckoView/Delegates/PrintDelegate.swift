//
//  PrintDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 22/9/26.
//

import Foundation

// NOTE (iOS 12 port): async/await replaced with a completion handler —
// Swift Concurrency is removed tree-wide (no libswift_Concurrency on iOS 12).
public protocol PrintDelegate: AnyObject {
    func onPrint(
        session: GeckoSession,
        browsingContextId: Int64?,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

private enum PrintEvents: String, CaseIterable {
    case request = "GeckoView:DotPrintRequest"
}

func newPrintHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewPrint",
        events: PrintEvents.allCases.map(\.rawValue),
        session: session
    ) { session, delegate, type, message, completion in
        guard PrintEvents(rawValue: type) == .request else {
            completion(.failure(GeckoHandlerError("unknown message \(type)")))
            return
        }
        
        let finish: (Bool) -> Void = { succeeded in
            session.dispatcher.dispatch(
                type: "GeckoView:DotPrintFinish",
                message: ["isPdfSuccessful": succeeded]
            )
        }
        
        guard let delegate = delegate as? PrintDelegate else {
            finish(false)
            completion(.success(nil))
            return
        }
        
        let browsingContextId = PayloadValue.int64(message?["canonicalBrowsingContextId"])
        delegate.onPrint(session: session, browsingContextId: browsingContextId) { result in
            switch result {
            case .success:
                finish(true)
                completion(.success(nil))
            case .failure(let error):
                finish(false)
                completion(.failure(error))
            }
        }
    }
}
