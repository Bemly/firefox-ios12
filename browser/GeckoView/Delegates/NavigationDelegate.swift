//
//  NavigationDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 22/2/26.
//

import Foundation

// MARK: - Navigation Models

public enum LoadRequestTarget {
    case current
    case new
    case background
}

public struct LoadRequest {
    public let uri: String
    public let triggerUri: String?
    public let target: LoadRequestTarget
    public let isRedirect: Bool
    public let hasUserGesture: Bool
    public let isUserInitiatedNavigation: Bool
    public let isDirectNavigation: Bool
}

private func loadRequestTarget(from value: Int32) -> LoadRequestTarget {
    switch value {
    case 0, 1:
        return .current
    case 5:
        return .background
    default:
        return .new
    }
}

private func loadRequest(from message: [String: Any?]?) -> LoadRequest? {
    guard let uri = message?["uri"] as? String else {
        return nil
    }
    
    let flags = PayloadValue.int(message?["flags"]) ?? 0
    let targetValue = PayloadValue.int32(message?["where"]) ?? 0
    let hasUserGesture = message?["hasUserGesture"] as? Bool ?? false
    let isRedirectFlag = 0x800000
    
    return LoadRequest(
        uri: uri,
        triggerUri: message?["triggerUri"] as? String,
        target: loadRequestTarget(from: targetValue),
        isRedirect: (flags & isRedirectFlag) != 0,
        hasUserGesture: hasUserGesture,
        isUserInitiatedNavigation:
            message?["isUserInitiatedNavigation"] as? Bool ?? hasUserGesture,
        isDirectNavigation: true
    )
}

// MARK: - Navigation Delegate

public protocol NavigationDelegate {
    func onLocationChange(session: GeckoSession, url: String?, permissions: [ContentPermission])
    func onCanGoBack(session: GeckoSession, canGoBack: Bool)
    func onCanGoForward(session: GeckoSession, canGoForward: Bool)
    func onLoadRequest(session: GeckoSession, request: LoadRequest, completion: @escaping (AllowOrDeny) -> Void)
    func onPreNavigation(session: GeckoSession, request: LoadRequest, completion: @escaping (AllowOrDeny) -> Void)
    func onSubframeLoadRequest(session: GeckoSession, request: LoadRequest, completion: @escaping (AllowOrDeny) -> Void)
    func onNewSession(
        session: GeckoSession,
        uri: String,
        windowId: String,
        target: LoadRequestTarget,
        completion: @escaping (GeckoSession?) -> Void
    )
}

extension NavigationDelegate {
    public func onLocationChange(session: GeckoSession, url: String?, permissions: [ContentPermission]) {}
    public func onCanGoBack(session: GeckoSession, canGoBack: Bool) {}
    public func onCanGoForward(session: GeckoSession, canGoForward: Bool) {}
    public func onLoadRequest(session: GeckoSession, request: LoadRequest, completion: @escaping (AllowOrDeny) -> Void) { completion(.allow) }
    public func onPreNavigation(session: GeckoSession, request: LoadRequest, completion: @escaping (AllowOrDeny) -> Void) { completion(.allow) }
    public func onSubframeLoadRequest(session: GeckoSession, request: LoadRequest, completion: @escaping (AllowOrDeny) -> Void) { completion(.allow) }
    public func onNewSession(session: GeckoSession, uri: String, windowId: String, target: LoadRequestTarget, completion: @escaping (GeckoSession?) -> Void) { completion(nil) }
}

// MARK: - Navigation Events

enum NavigationEvents: String, CaseIterable {
    case locationChange = "GeckoView:LocationChange"
    case onNewSession = "GeckoView:OnNewSession"
    case onLoadError = "GeckoView:OnLoadError"
    case onLoadRequest = "GeckoView:OnLoadRequest"
    case preNavigation = "GeckoView:OnPreNavigation"
}

// MARK: - Navigation Handler

func newNavigationHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewNavigation",
        events: NavigationEvents.allCases.map(\.rawValue),
        session: session
    ) {  session, delegate, type, message, completion in
        guard let event = NavigationEvents(rawValue: type) else {
            completion(.failure(GeckoHandlerError("unknown message \(type)")))
            return
        }

        let delegate = delegate as? NavigationDelegate
        switch event {
        case .locationChange:
            if message?["isTopLevel"] as? Bool == true {
                let permissionPayloads = message?["permissions"] as? [[String: Any?]]
                delegate?.onLocationChange(
                    session: session,
                    url: message?["uri"] as? String,
                    permissions: permissionPayloads?.map(ContentPermission.fromDictionary) ?? []
                )
            }
            
            delegate?.onCanGoBack(session: session, canGoBack: message?["canGoBack"] as? Bool ?? false)
            delegate?.onCanGoForward(
                session: session,
                canGoForward: message?["canGoForward"] as? Bool ?? false
            )
            completion(.success(nil))

        case .onNewSession:
            guard
                let uri = message?["uri"] as? String,
                let requestedWindowID = message?["newSessionId"] as? String
            else {
                completion(.success(false))
                return
            }

            let target = loadRequestTarget(
                from: PayloadValue.int32(message?["where"]) ?? 2
            )

            guard let delegate else {
                completion(.success(false))
                return
            }

            delegate.onNewSession(
                session: session,
                uri: uri,
                windowId: requestedWindowID,
                target: target
            ) { newSession in
                guard let newSession else {
                    completion(.success(false))
                    return
                }

                if let windowId = newSession.id,
                   windowId != requestedWindowID {
                    assertionFailure("GeckoSession was opened with mismatched window id")
                    completion(.success(false))
                    return
                }
                if !newSession.isOpen() {
                    newSession.open(windowId: requestedWindowID)
                }
                completion(.success(true))
            }

        case .onLoadError:
            NSLog("[PROBE] OnLoadError message=%@", String(describing: message))
            completion(.success(nil))

        case .onLoadRequest:
            guard let request = loadRequest(from: message) else {
                completion(.success(true))
                return
            }

            guard let delegate else {
                completion(.success(false))
                return
            }

            let isTopLevel = message?["isTopLevel"] as? Bool ?? true
            if isTopLevel {
                // GeckoView expects this response to mean "handled by the app".
                // Allow must therefore return false so Gecko continues the load itself.
                delegate.onLoadRequest(session: session, request: request) { decision in
                    completion(.success(decision == .deny))
                }
            } else {
                delegate.onSubframeLoadRequest(session: session, request: request) { decision in
                    completion(.success(decision == .deny))
                }
            }
        case .preNavigation:
            guard let request = loadRequest(from: message) else {
                completion(.success(true))
                return
            }
            delegate?.onPreNavigation(session: session, request: request) { decision in
                completion(.success(decision == .deny))
            }
        }
    }
}
