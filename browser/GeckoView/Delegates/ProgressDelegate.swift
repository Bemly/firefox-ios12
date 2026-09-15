//
//  ProgressDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 22/2/26.
//

import Foundation

// MARK: - Progress Delegate

public protocol ProgressDelegate {
    func onPageStart(session: GeckoSession, url: String)
    func onPageStop(session: GeckoSession, success: Bool)
    func onProgressChange(session: GeckoSession, progress: Int)
    func onSessionStateChange(session: GeckoSession, sessionState: GeckoSessionState)
}

extension ProgressDelegate {
    public func onPageStart(session: GeckoSession, url: String) {}
    public func onPageStop(session: GeckoSession, success: Bool) {}
    public func onProgressChange(session: GeckoSession, progress: Int) {}
    public func onSessionStateChange(session: GeckoSession, sessionState: GeckoSessionState) {}
}

// MARK: - Progress Events

enum ProgressEvents: String, CaseIterable {
    case pageStart = "GeckoView:PageStart"
    case pageStop = "GeckoView:PageStop"
    case progressChanged = "GeckoView:ProgressChanged"
    case securityChanged = "GeckoView:SecurityChanged"
    case stateUpdated = "GeckoView:StateUpdated"
}

// MARK: - Progress Handler

func newProgressHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewProgress",
        events: ProgressEvents.allCases.map(\.rawValue),
        session: session
    ) {  session, delegate, type, message, completion in
        guard let event = ProgressEvents(rawValue: type) else {
            completion(.failure(GeckoHandlerError("unknown message \(type)")))
            return
        }

        let delegate = delegate as? ProgressDelegate
        switch event {
        case .pageStart:
            if let url = message?["uri"] as? String {
                    delegate?.onPageStart(session: session, url: url)
            }
        case .pageStop:
            delegate?.onPageStop(session: session, success: message?["success"] as? Bool ?? false)
        case .progressChanged:
            delegate?.onProgressChange(session: session, progress: message?["progress"] as? Int ?? 0)
        case .securityChanged:
            break
        case .stateUpdated:
            guard session.historyDelegate == nil,
                  let data = message?["data"] as? [String: Any] else {
                break
            }
            session.handleSessionStateUpdate(data)
        }
        completion(.success(nil))
    }
}
