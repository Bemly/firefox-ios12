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
    
    @MainActor
    func handleMessage(type: String, message: [String: Any?]?) async throws -> Any? {
        guard let session else {
            throw GeckoHandlerError("session has been destroyed")
        }
        if type == "GeckoView:WebExtension:Connect" || type == "GeckoView:WebExtension:Message" {
            return try await handleAddonMessage(type: type, message: message, session: session)
        }
        return try await AddonRuntime.shared.handleSessionEvent(
            type: type,
            message: message,
            session: session
        )
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
