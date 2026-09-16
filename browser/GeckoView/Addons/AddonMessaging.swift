//
//  AddonMessaging.swift
//  Reynard
//

import Foundation

public enum AddonMessageEnvironment: Equatable {
    case contentScript
    case extensionPage
    case unknown
}

public final class AddonMessageSender {
    public let extensionID: String
    public private(set) weak var session: GeckoSession?
    public let sessionIdentifier: ObjectIdentifier
    public let url: String?
    public let environment: AddonMessageEnvironment
    public let isTopLevel: Bool
    
    init(
        extensionID: String,
        session: GeckoSession,
        url: String?,
        environment: AddonMessageEnvironment,
        isTopLevel: Bool
    ) {
        self.extensionID = extensionID
        self.session = session
        sessionIdentifier = ObjectIdentifier(session)
        self.url = url
        self.environment = environment
        self.isTopLevel = isTopLevel
    }
}

@MainActor
public protocol AddonMessageDelegate: AnyObject {
    func addonMessage(
        _ message: Any,
        nativeApp: String,
        sender: AddonMessageSender
    ) async throws -> Any?
    func addonPortDidConnect(_ port: AddonPort)
}

public extension AddonMessageDelegate {
    func addonMessage(
        _ message: Any,
        nativeApp: String,
        sender: AddonMessageSender
    ) async throws -> Any? {
        return nil
    }
    
    func addonPortDidConnect(_ port: AddonPort) {}
}

@MainActor
public protocol AddonPortDelegate: AnyObject {
    func addonPort(_ port: AddonPort, didReceive message: Any)
    func addonPortDidDisconnect(_ port: AddonPort)
}

public extension AddonPortDelegate {
    func addonPort(_ port: AddonPort, didReceive message: Any) {}
    func addonPortDidDisconnect(_ port: AddonPort) {}
}

@MainActor
public final class AddonPort: GeckoEventListenerInternal {
    public let id: Int64
    public let name: String
    public let sender: AddonMessageSender
    public weak var delegate: AddonPortDelegate?
    
    private let dispatcherName: String
    private let dispatcher: GeckoEventDispatcherWrapper
    private var isDisconnected = false
    
    init(id: Int64, name: String, sender: AddonMessageSender) {
        self.id = id
        self.name = name
        self.sender = sender
        dispatcherName = "port:\(id)"
        dispatcher = GeckoEventDispatcherWrapper.lookup(byName: dispatcherName)
        dispatcher.addListener(type: "GeckoView:WebExtension:PortMessage", listener: self)
        dispatcher.addListener(type: "GeckoView:WebExtension:Disconnect", listener: self)
    }
    
    public func postMessage(_ message: [String: Any?]) {
        guard !isDisconnected else { return }
        dispatcher.dispatch(
            type: "GeckoView:WebExtension:PortMessageFromApp",
            message: ["message": message]
        )
    }
    
    public func disconnect() {
        guard !isDisconnected else { return }
        dispatcher.dispatch(
            type: "GeckoView:WebExtension:PortDisconnect",
            message: ["portId": id]
        )
        close(notifyingDelegate: false)
    }
    
    @MainActor
    func handleMessage(type: String, message: [String: Any?]?) async throws -> Any? {
        switch type {
        case "GeckoView:WebExtension:PortMessage":
            if let data = message?["data"], let value = data {
                delegate?.addonPort(self, didReceive: value)
            }
        case "GeckoView:WebExtension:Disconnect":
            close(notifyingDelegate: true)
        default:
            throw GeckoHandlerError("Unknown WebExtension port event \(type)")
        }
        return nil
    }
    
    private func close(notifyingDelegate: Bool) {
        guard !isDisconnected else { return }
        isDisconnected = true
        dispatcher.removeListener(type: "GeckoView:WebExtension:PortMessage", listener: self)
        dispatcher.removeListener(type: "GeckoView:WebExtension:Disconnect", listener: self)
        GeckoEventDispatcherWrapper.removeDispatcher(named: dispatcherName, matching: dispatcher)
        if notifyingDelegate {
            delegate?.addonPortDidDisconnect(self)
        }
    }
}

struct AddonMessageRegistrationKey: Hashable {
    let extensionID: String
    let nativeApp: String
}

final class WeakAddonMessageDelegate {
    weak var value: AddonMessageDelegate?
    
    init(_ value: AddonMessageDelegate) {
        self.value = value
    }
}

extension AddonSessionListener {
    func setMessageDelegate(
        _ delegate: AddonMessageDelegate?,
        extensionID: String,
        nativeApp: String
    ) {
        let key = AddonMessageRegistrationKey(extensionID: extensionID, nativeApp: nativeApp)
        if let delegate {
            messageDelegates[key] = WeakAddonMessageDelegate(delegate)
        } else {
            messageDelegates.removeValue(forKey: key)
        }
    }
    
    @MainActor
    func handleAddonMessage(
        type: String,
        message: [String: Any?]?,
        session: GeckoSession
    ) async throws -> Any? {
        guard let extensionID = message?["extensionId"] as? String,
              let nativeApp = message?["nativeApp"] as? String else {
            throw GeckoHandlerError("Missing WebExtension message recipient")
        }
        let key = AddonMessageRegistrationKey(extensionID: extensionID, nativeApp: nativeApp)
        guard let delegate = messageDelegates[key]?.value else {
            messageDelegates.removeValue(forKey: key)
            throw GeckoHandlerError("No WebExtension message delegate registered")
        }
        
        let senderPayload = message?["sender"] as? [String: Any?] ?? [:]
        let environment: AddonMessageEnvironment
        switch senderPayload["envType"] as? String {
        case "content_child":
            environment = .contentScript
        case "addon_child":
            environment = .extensionPage
        default:
            environment = .unknown
        }
        let frameID = PayloadValue.int(senderPayload["frameId"] ?? nil)
        let sender = AddonMessageSender(
            extensionID: extensionID,
            session: session,
            url: senderPayload["url"] as? String,
            environment: environment,
            isTopLevel: environment == .extensionPage || frameID == 0
        )
        
        switch type {
        case "GeckoView:WebExtension:Connect":
            guard let portID = PayloadValue.int64(message?["portId"] ?? nil) else {
                throw GeckoHandlerError("Missing WebExtension port ID")
            }
            let port = AddonPort(id: portID, name: nativeApp, sender: sender)
            delegate.addonPortDidConnect(port)
            return true
        case "GeckoView:WebExtension:Message":
            return try await delegate.addonMessage(
                message?["data"] ?? NSNull(),
                nativeApp: nativeApp,
                sender: sender
            )
        default:
            throw GeckoHandlerError("Unknown WebExtension message event \(type)")
        }
    }
}
