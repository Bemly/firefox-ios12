//
//  HistoryDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 11/7/26.
//

import Foundation

public struct HistoryVisitFlags: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let topLevel = HistoryVisitFlags(rawValue: 1 << 0)
    public static let redirectTemporary = HistoryVisitFlags(rawValue: 1 << 1)
    public static let redirectPermanent = HistoryVisitFlags(rawValue: 1 << 2)
    public static let redirectSource = HistoryVisitFlags(rawValue: 1 << 3)
    public static let redirectSourcePermanent = HistoryVisitFlags(rawValue: 1 << 4)
    public static let unrecoverableError = HistoryVisitFlags(rawValue: 1 << 5)
}

// MARK: - History Delegate

public protocol HistoryDelegate: AnyObject {
    func onVisited(
        session: GeckoSession,
        url: String,
        lastVisitedURL: String?,
        flags: HistoryVisitFlags,
        completion: @escaping (Bool) -> Void
    )
    func getVisited(session: GeckoSession, urls: [String], completion: @escaping ([Bool]?) -> Void)
    func onHistoryStateChange(session: GeckoSession, sessionState: GeckoSessionState)
}

public extension HistoryDelegate {
    func onVisited(
        session: GeckoSession,
        url: String,
        lastVisitedURL: String?,
        flags: HistoryVisitFlags,
        completion: @escaping (Bool) -> Void
    ) {
        completion(false)
    }

    func getVisited(session: GeckoSession, urls: [String], completion: @escaping ([Bool]?) -> Void) {
        completion(nil)
    }

    func onHistoryStateChange(session: GeckoSession, sessionState: GeckoSessionState) {}
}

// MARK: - History Events
// MARK: - History Events

enum HistoryEvents: String, CaseIterable {
    case onVisited = "GeckoView:OnVisited"
    case getVisited = "GeckoView:GetVisited"
    case stateUpdated = "GeckoView:StateUpdated"
}

// MARK: - History Handler

func newHistoryHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewHistory",
        events: HistoryEvents.allCases.map(\.rawValue),
        session: session
    ) { session, delegate, type, message, completion in
        guard let event = HistoryEvents(rawValue: type) else {
            completion(.failure(GeckoHandlerError("unknown message \(type)")))
            return
        }

        guard let delegate = delegate as? HistoryDelegate else {
            completion(.failure(GeckoHandlerError("history delegate not attached")))
            return
        }
        switch event {
        case .onVisited:
            guard let url = message?["url"] as? String else {
                completion(.success(false))
                return
            }

            delegate.onVisited(
                session: session,
                url: url,
                lastVisitedURL: message?["lastVisitedURL"] as? String,
                flags: HistoryVisitFlags(rawValue: PayloadValue.int(message?["flags"]) ?? 0)
            ) { completion(.success($0)) }

        case .getVisited:
            let urls = PayloadValue.strings(message?["urls"])
            delegate.getVisited(session: session, urls: urls) { completion(.success($0)) }
        case .stateUpdated:
            guard let data = message?["data"] as? [String: Any] else {
                completion(.success(nil))
                return
            }
            session.handleSessionStateUpdate(data)
            completion(.success(nil))
        }
    }
}
