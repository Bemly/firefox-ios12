//
//  AddonRuntimeCommands.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import Foundation

public extension AddonRuntime {
    // Ported from upstream ensureBuiltIn (async -> completion, iOS 12 has no Concurrency runtime).
    func ensureBuiltIn(location: String, id: String, completion: @escaping (Result<Addon, Error>) -> Void) {
        GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:WebExtension:EnsureBuiltIn",
            message: [
                "locationUri": location,
                "webExtensionId": id,
            ]
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let payload = response as? [String: Any?],
                      let addonPayload = payload["extension"] as? [String: Any?] else {
                    completion(.failure(GeckoHandlerError("Invalid built-in extension response")))
                    return
                }
                completion(.success(Addon(dictionary: addonPayload)))
            }
        }
    }

    func list(completion: @escaping (Result<[Addon], Error>) -> Void) {
        GeckoEventDispatcherWrapper.runtimeInstance.query(type: "GeckoView:WebExtension:List") { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let payload = response as? [String: Any?] else {
                    completion(.success(Array(self.addonsByID.values)))
                    return
                }

                let entries = payload["extensions"] as? [[String: Any?]] ?? []
                let listedAddonIDs = Set(entries.compactMap { $0["webExtensionId"] as? String })
                let staleAddonIDs = self.addonsByID.keys.filter { !listedAddonIDs.contains($0) }
                let removedAddons = staleAddonIDs.compactMap { self.removeAddon(byID: $0) }
                entries.forEach { _ = self.upsertAddon(from: $0) }
                removedAddons.forEach { self.delegate?.addonController(self, didUpdate: $0) }
                completion(.success(self.installedAddons))
            }
        }
    }

    func addon(byID id: String, completion: @escaping (Result<Addon?, Error>) -> Void) {
        if let cached = addonsByID[id] {
            completion(.success(cached))
            return
        }

        GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:WebExtension:Get",
            message: ["extensionId": id]
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let payload = response as? [String: Any?],
                      let addonPayload = payload["extension"] as? [String: Any?] else {
                    completion(.success(nil))
                    return
                }
                completion(.success(self.upsertAddon(from: addonPayload)))
            }
        }
    }

    func install(url: String, installMethod: AddonInstallMethod? = nil, completion: @escaping (Result<Addon, Error>) -> Void) {
        installCounter += 1
        GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:WebExtension:Install",
            message: [
                "locationUri": url,
                "installId": "reynard-\(installCounter)",
                "installMethod": installMethod?.rawValue as Any,
            ]
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let payload = response as? [String: Any?],
                      let addonPayload = payload["extension"] as? [String: Any?] else {
                    completion(.failure(GeckoHandlerError("Invalid install response")))
                    return
                }
                let addon = self.upsertAddon(from: addonPayload)
                self.delegate?.addonController(self, didUpdate: addon)
                completion(.success(addon))
            }
        }
    }

    func enable(_ addon: Addon, source: AddonEnableSource = .user, completion: @escaping (Result<Addon, Error>) -> Void) {
        mutateAddon(
            type: "GeckoView:WebExtension:Enable",
            message: ["webExtensionId": addon.id, "source": source.rawValue],
            completion: completion
        )
    }

    func disable(_ addon: Addon, source: AddonEnableSource = .user, completion: @escaping (Result<Addon, Error>) -> Void) {
        mutateAddon(
            type: "GeckoView:WebExtension:Disable",
            message: ["webExtensionId": addon.id, "source": source.rawValue],
            completion: completion
        )
    }

    func setAllowedInPrivateBrowsing(_ addon: Addon, allowed: Bool, completion: @escaping (Result<Addon, Error>) -> Void) {
        mutateAddon(
            type: "GeckoView:WebExtension:SetPBAllowed",
            message: ["extensionId": addon.id, "allowed": allowed],
            completion: completion
        )
    }

    func addOptionalPermissions(_ request: AddonPermissionChangeRequest, to addon: Addon, completion: @escaping (Result<Addon, Error>) -> Void) {
        mutateAddon(
            type: "GeckoView:WebExtension:AddOptionalPermissions",
            message: [
                "extensionId": addon.id,
                "permissions": request.permissions,
                "origins": request.origins,
                "dataCollectionPermissions": request.dataCollectionPermissions,
            ],
            completion: completion
        )
    }

    func removeOptionalPermissions(_ request: AddonPermissionChangeRequest, from addon: Addon, completion: @escaping (Result<Addon, Error>) -> Void) {
        mutateAddon(
            type: "GeckoView:WebExtension:RemoveOptionalPermissions",
            message: [
                "extensionId": addon.id,
                "permissions": request.permissions,
                "origins": request.origins,
                "dataCollectionPermissions": request.dataCollectionPermissions,
            ],
            completion: completion
        )
    }

    func uninstall(_ addon: Addon, completion: @escaping (Result<Void, Error>) -> Void) {
        GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:WebExtension:Uninstall",
            message: ["webExtensionId": addon.id]
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                if let removedAddon = self.removeAddon(byID: addon.id) {
                    self.delegate?.addonController(self, didUpdate: removedAddon)
                }
                completion(.success(()))
            }
        }
    }

    func update(_ addon: Addon, completion: @escaping (Result<Addon?, Error>) -> Void) {
        GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:WebExtension:Update",
            message: ["webExtensionId": addon.id]
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let payload = response as? [String: Any?],
                      let addonPayload = payload["extension"] as? [String: Any?] else {
                    completion(.success(nil))
                    return
                }
                let updatedAddon = self.upsertAddon(from: addonPayload)
                self.delegate?.addonController(self, didUpdate: updatedAddon)
                completion(.success(updatedAddon))
            }
        }
    }

    func clickAction(kind: AddonActionKind, addon: Addon, completion: @escaping (Result<String?, Error>) -> Void) {
        let event = kind == .browser ? "GeckoView:BrowserAction:Click" : "GeckoView:PageAction:Click"
        GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: event,
            message: ["extensionId": addon.id]
        ) { result in
            completion(result.map { $0 as? String })
        }
    }
}

extension AddonRuntime {
    func mutateAddon(type: String, message: [String: Any?], completion: @escaping (Result<Addon, Error>) -> Void) {
        GeckoEventDispatcherWrapper.runtimeInstance.query(type: type, message: message) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let payload = response as? [String: Any?],
                      let addonPayload = payload["extension"] as? [String: Any?] else {
                    completion(.failure(GeckoHandlerError("Invalid extension response")))
                    return
                }
                let updatedAddon = self.upsertAddon(from: addonPayload)
                self.delegate?.addonController(self, didUpdate: updatedAddon)
                completion(.success(updatedAddon))
            }
        }
    }
}
