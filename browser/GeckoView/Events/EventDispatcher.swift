//
//  GeckoEventDispatcher.swift
//  Reynard
//
//  Created by Minh Ton on 1/2/26.
//

import Foundation

struct GeckoHandlerError: Error {
    let value: Any?
    
    init(_ value: Any?) {
        self.value = value
    }
}

protocol GeckoEventListenerInternal {
    
    func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?)
}

public class GeckoEventDispatcherWrapper: NSObject, SwiftEventDispatcher {
    static var runtimeInstance = GeckoEventDispatcherWrapper()
    static var dispatchers: [String: GeckoEventDispatcherWrapper] = [:]
    
    struct QueuedMessage {
        let type: String
        let message: [String: Any?]?
        let callback: EventCallback?
    }
    
    var gecko: (any GeckoEventDispatcher)?
    var queue: [QueuedMessage]? = []
    var listeners: [String: [GeckoEventListenerInternal]] = [:]
    var name: String?
    
    override init() {}
    
    init(name: String) {
        self.name = name
    }
    
    public static func lookup(byName: String) -> GeckoEventDispatcherWrapper {
        if let dispatcher = dispatchers[byName] {
            return dispatcher
        }
        let dispatcher = GeckoEventDispatcherWrapper(name: byName)
        dispatchers[byName] = dispatcher
        return dispatcher
    }
    
    func addListener(type: String, listener: GeckoEventListenerInternal) {
        listeners[type, default: []] += [listener]
    }
    
    public func dispatch(
        type: String, message: [String: Any?]? = nil, callback: EventCallback? = nil
    ) {
        if let registeredListeners = listeners[type] {
            NSLog("[PROBE] dispatch %@ -> local(%d listeners)", type, registeredListeners.count)
            for listener in registeredListeners {
                listener.handleMessage(type: type, message: message, callback: callback)
            }
        } else if queue != nil {
            NSLog("[PROBE] dispatch %@ -> QUEUED(len=%d) gecko=%@", type, queue?.count ?? -1, String(describing: gecko))
            queue?.append(QueuedMessage(type: type, message: message, callback: callback))
        } else {
            NSLog("[PROBE] dispatch %@ -> toGecko", type)
            gecko?.dispatch(toGecko: type, message: message, callback: callback)
        }
    }
    
    public func query(
        type: String,
        message: [String: Any?]? = nil,
        completion: @escaping (Result<Any?, Error>) -> Void
    ) {
        class CallbackAdapter: NSObject, EventCallback {
            var completion: ((Result<Any?, Error>) -> Void)?
            init(_ completion: @escaping (Result<Any?, Error>) -> Void) {
                self.completion = completion
            }
            func sendSuccess(_ response: Any?) {
                completion?(.success(response))
                completion = nil
            }
            func sendError(_ response: Any?) {
                completion?(.failure(GeckoHandlerError(response)))
                completion = nil
            }
            deinit {
                completion?(.failure(GeckoHandlerError("callback never invoked")))
                completion = nil
            }
        }

        dispatch(type: type, message: message, callback: CallbackAdapter(completion))
    }
    
    public func attach(_ dispatcher: (any GeckoEventDispatcher)?) {
        NSLog("[PROBE] dispatcher attach gecko=%@", String(describing: dispatcher))
        gecko = dispatcher
    }
    
    public func dispatch(toSwift type: String!, message: Any!, callback: EventCallback?) {
        let message = message as! [String: Any?]?
        if let registeredListeners = listeners[type] {
            for listener in registeredListeners {
                listener.handleMessage(type: type, message: message, callback: callback)
            }
        }
    }
    
    public func activate() {
        NSLog("[PROBE] dispatcher activate flush=%d", queue?.count ?? -1)
        if let queue = self.queue {
            self.queue = nil
            for event in queue {
                gecko?.dispatch(toGecko: event.type, message: event.message, callback: event.callback)
            }
        }
    }
    
    public func hasListener(_ type: String!) -> Bool {
        listeners.keys.contains(type)
    }
}
