//
//  AddonSession.swift
//  Reynard
//
//  Created by Minh Ton on 28/4/26.
//

import Foundation

public struct AddonCreateTabDetails {
    public let active: Bool?
    public let index: Int?
    public let url: String?
    
    init(dictionary: [String: Any?]) {
        active = dictionary["active"] as? Bool
        index = PayloadValue.int(dictionary["index"] ?? nil)
        url = dictionary["url"] as? String
    }
}

public struct AddonUpdateTabDetails {
    public let active: Bool?
    public let url: String?
    
    init(dictionary: [String: Any?]) {
        active = dictionary["active"] as? Bool
        url = dictionary["url"] as? String
    }
}

final class AddonSessionListener: GeckoEventListenerInternal {
    weak var session: GeckoSession?
    var messageDelegates: [AddonMessageRegistrationKey: WeakAddonMessageDelegate] = [:]
    
    init(session: GeckoSession) {
        self.session = session
    }
    
    let events: [String] = [
        "GeckoView:BrowserAction:Update",
        "GeckoView:BrowserAction:OpenPopup",
        "GeckoView:PageAction:Update",
        "GeckoView:PageAction:OpenPopup",
        "GeckoView:WebExtension:OpenOptionsPage",
        "GeckoView:WebExtension:NewTab",
        "GeckoView:WebExtension:UpdateTab",
        "GeckoView:WebExtension:CloseTab",
        "GeckoView:WebExtension:Connect",
        "GeckoView:WebExtension:Message",
    ]
    
    
    func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        guard let session else {
            callback?.sendError(GeckoHandlerError("session has been destroyed").value)
            return
        }
        if type == "GeckoView:WebExtension:Connect" || type == "GeckoView:WebExtension:Message" {
            handleAddonMessage(type: type, message: message, session: session) { result in
                switch result {
                case .success(let value):
                    callback?.sendSuccess(value)
                case .failure(let error as GeckoHandlerError):
                    callback?.sendError(error.value)
                case .failure(let error):
                    callback?.sendError("\(error)")
                }
            }
            return
        }
        AddonRuntime.shared.handleSessionEvent(
            type: type,
            message: message,
            session: session
        ) { result in
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

public extension GeckoSession {
    func setAddonTabActive(_ active: Bool) {
        dispatcher.dispatch(type: "GeckoView:WebExtension:SetTabActive", message: ["active": active])
    }
    
    func setAddonMessageDelegate(
        _ delegate: AddonMessageDelegate?,
        extensionID: String,
        nativeApp: String
    ) {
        addonSessionListener.setMessageDelegate(
            delegate,
            extensionID: extensionID,
            nativeApp: nativeApp
        )
    }
}
