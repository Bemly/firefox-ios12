//
//  Helper.swift
//  Reynard
//
//  Created by Minh Ton on 25/2/26.
//

import GeckoView
import Foundation

@objc private protocol BootstrapPing {
    func ping()
}


private final class ProcessBootstrap {
    private static var connection: NSXPCConnection?
    
    static func start(
        context: NSExtensionContext,
        process: GeckoProcessExtension
    ) throws {
        guard connection == nil else {
            throw NSError(
                domain: "Reynard.ProcessBootstrap",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Gecko child process already started"]
            )
        }
        guard
            let input = context.inputItems.first as? NSExtensionItem,
            let userInfo = input.userInfo,
            let endpoint = userInfo["ReynardXPCListenerEndpoint"] as? NSXPCListenerEndpoint
        else {
            throw NSError(
                domain: "Reynard.ProcessBootstrap",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing NSXPC listener endpoint"]
            )
        }
        
        let connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.remoteObjectInterface = NSXPCInterface(with: BootstrapPing.self)
        connection.resume()
        
        guard let xpcConnection = XPCConnectionFromNSXPC(connection) else {
            connection.invalidate()
            throw NSError(
                domain: "Reynard.ProcessBootstrap",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to bridge NSXPCConnection to libxpc"]
            )
        }
        
        self.connection = connection
        GeckoRuntime.childMain(xpcConnection: xpcConnection, process: process)
        (connection.remoteObjectProxyWithErrorHandler({ _ in }) as? BootstrapPing)?.ping()
    }
}

open class BrowserHelper: NSObject, GeckoProcessExtension, NSExtensionRequestHandling {
	public required override init() {
		super.init()
	}

	open func beginRequest(with context: NSExtensionContext) {
		DispatchQueue.main.async {
			do {
				try ProcessBootstrap.start(context: context, process: self)
			} catch {
				context.cancelRequest(withError: error)
			}
		}
	}

	open func lockdownSandbox(_ revision: String!) {}
}

@objc(ReynardHelperMain)
final class ReynardHelperMain: BrowserHelper {}
