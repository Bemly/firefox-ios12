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

public protocol AddonMessageDelegate: AnyObject {
    func addonMessage(
        _ message: Any,
        nativeApp: String,
        sender: AddonMessageSender,
        completion: @escaping (Result<Any?, Error>) -> Void
    )
    func addonPortDidConnect(_ port: AddonPort)
}

public extension AddonMessageDelegate {
    func addonMessage(
        _ message: Any,
        nativeApp: String,
        sender: AddonMessageSender,
        completion: @escaping (Result<Any?, Error>) -> Void
    ) {
        completion(.success(nil))
    }

    func addonPortDidConnect(_ port: AddonPort) {}
}

public protocol AddonPortDelegate: AnyObject {
    func addonPort(_ port: AddonPort, didReceive message: Any)
    func addonPortDidDisconnect(_ port: AddonPort)
}

public extension AddonPortDelegate {
    func addonPort(_ port: AddonPort, didReceive message: Any) {}
    func addonPortDidDisconnect(_ port: AddonPort) {}
}

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
    
    func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        switch type {
        case "GeckoView:WebExtension:PortMessage":
            if let data = message?["data"], let value = data {
                delegate?.addonPort(self, didReceive: value)
            }
            callback?.sendSuccess(nil)
        case "GeckoView:WebExtension:Disconnect":
            close(notifyingDelegate: true)
            callback?.sendSuccess(nil)
        default:
            callback?.sendError(GeckoHandlerError("Unknown WebExtension port event \(type)").value)
        }
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
    
    func handleAddonMessage(
        type: String,
        message: [String: Any?]?,
        session: GeckoSession,
        completion: @escaping (Result<Any?, Error>) -> Void
    ) {
        guard let extensionID = message?["extensionId"] as? String,
              let nativeApp = message?["nativeApp"] as? String else {
            completion(.failure(GeckoHandlerError("Missing WebExtension message recipient")))
            return
        }
        let key = AddonMessageRegistrationKey(extensionID: extensionID, nativeApp: nativeApp)
        guard let delegate = messageDelegates[key]?.value else {
            messageDelegates.removeValue(forKey: key)
            completion(.failure(GeckoHandlerError("No WebExtension message delegate registered")))
            return
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
                completion(.failure(GeckoHandlerError("Missing WebExtension port ID")))
                return
            }
            let port = AddonPort(id: portID, name: nativeApp, sender: sender)
            delegate.addonPortDidConnect(port)
            completion(.success(true))
        case "GeckoView:WebExtension:Message":
            delegate.addonMessage(
                message?["data"] ?? NSNull(),
                nativeApp: nativeApp,
                sender: sender,
                completion: completion
            )
        default:
            completion(.failure(GeckoHandlerError("Unknown WebExtension message event \(type)")))
        }
    }
}
