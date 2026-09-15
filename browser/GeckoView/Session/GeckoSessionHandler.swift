//
//  GeckoSessionHandler.swift
//  Reynard
//
//  Created by Minh Ton on 22/2/26.
//

import Foundation

final class GeckoSessionHandler: GeckoSessionHandlerCommon {
    typealias MessageCompletion = (Result<Any?, Error>) -> Void
    typealias MessageHandler =  (GeckoSession, Any?, String, [String: Any?]?, @escaping MessageCompletion) -> Void
    
    let moduleName: String?
    let events: [String]
    let handle: MessageHandler
    
    private(set) weak var session: GeckoSession?
    private var delegateReference: Any?
    
    func delegate<Delegate>(as type: Delegate.Type = Delegate.self) -> Delegate? {
        return delegateReference as? Delegate
    }
    
    var enabled: Bool {
        return delegateReference != nil
    }
    
    func setDelegate<Delegate>(_ delegate: Delegate?) {
        delegateReference = delegate
        
        guard let moduleName, let session, session.isOpen() else {
            return
        }
        
        session.dispatcher.dispatch(
            type: "GeckoView:UpdateModuleState",
            message: [
                "module": moduleName,
                "enabled": delegate != nil,
            ])
    }
    
    init(
        moduleName: String,
        events: [String],
        session: GeckoSession,
        handle: @escaping MessageHandler
    ) {
        self.moduleName = moduleName
        self.events = events
        self.session = session
        self.handle = handle
    }
    
    
    func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        guard events.contains(type) else {
            callback?.sendError(GeckoHandlerError("unknown message \(type)").value)
            return
        }
        guard let session else {
            callback?.sendError(GeckoHandlerError("session has been destroyed").value)
            return
        }
        handle(session, delegateReference, type, message) { result in
            switch result {
            case .success(let value):
                callback?.sendSuccess(value)
            case .failure(let error as GeckoHandlerError):
                callback?.sendError(error.value)
            case .failure(let error):
                callback?.sendError("\(error)")
            }
        }
    }
}
