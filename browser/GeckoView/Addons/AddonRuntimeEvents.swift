//
//  AddonRuntimeEvents.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import Foundation

extension AddonRuntime {
    
    func handleSessionEvent(type: String, message: [String: Any?]?, session: GeckoSession, completion: @escaping (Result<Any?, Error>) -> Void) {
        switch type {
        case "GeckoView:BrowserAction:Update":
            handleActionUpdate(kind: .browser, message: message, session: session) { completion($0.map { _ in nil }) }
        case "GeckoView:PageAction:Update":
            handleActionUpdate(kind: .page, message: message, session: session) { completion($0.map { _ in nil }) }
        case "GeckoView:BrowserAction:OpenPopup":
            handleOpenPopup(kind: .browser, message: message, session: session) { completion($0.map { _ in nil }) }
        case "GeckoView:PageAction:OpenPopup":
            handleOpenPopup(kind: .page, message: message, session: session) { completion($0.map { _ in nil }) }
        case "GeckoView:WebExtension:OpenOptionsPage":
            handleOpenOptionsPage(message: message) { completion($0.map { _ in nil }) }
        case "GeckoView:WebExtension:NewTab":
            handleNewTab(message: message) { completion($0.map { $0 as Any? }) }
        case "GeckoView:WebExtension:UpdateTab":
            guard let extensionID = message?["extensionId"] as? String else {
                completion(.failure(GeckoHandlerError("tabs.update is not supported")))
                return
            }
            addon(byID: extensionID) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let addon):
                    guard let addon else {
                        completion(.failure(GeckoHandlerError("tabs.update is not supported")))
                        return
                    }
                    let details = AddonUpdateTabDetails(
                        dictionary: message?["updateProperties"] as? [String: Any?] ?? [:]
                    )
                    if self.delegate?.addonController(self, updateTab: session, for: addon, details: details) == .allow {
                        completion(.success(nil))
                    } else {
                        completion(.failure(GeckoHandlerError("tabs.update is not supported")))
                    }
                }
            }
        case "GeckoView:WebExtension:CloseTab":
            guard let extensionID = message?["extensionId"] as? String else {
                completion(.failure(GeckoHandlerError("tabs.remove is not supported")))
                return
            }
            addon(byID: extensionID) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let addon):
                    guard let addon else {
                        completion(.failure(GeckoHandlerError("tabs.remove is not supported")))
                        return
                    }
                    if self.delegate?.addonController(self, closeTab: session, for: addon) == .allow {
                        completion(.success(nil))
                    } else {
                        completion(.failure(GeckoHandlerError("tabs.remove is not supported")))
                    }
                }
            }
        default:
            completion(.failure(GeckoHandlerError("Unhandled WebExtension session event \(type)")))
        }
    }

    
    public func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        guard let event = AddonRuntimeEvent(rawValue: type) else {
            callback?.sendError(GeckoHandlerError("unknown message \(type)").value)
            return
        }

        handleRuntimeEvent(event, message: message) { result in
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

    private func handleRuntimeEvent(_ event: AddonRuntimeEvent, message: [String: Any?]?, completion: @escaping (Result<Any?, Error>) -> Void) {
        switch event {
        case .browserActionUpdate:
            handleActionUpdate(kind: .browser, message: message, session: nil) { completion($0.map { _ in nil }) }
        case .pageActionUpdate:
            handleActionUpdate(kind: .page, message: message, session: nil) { completion($0.map { _ in nil }) }
        case .browserActionOpenPopup:
            handleOpenPopup(kind: .browser, message: message, session: nil) { completion($0.map { _ in nil }) }
        case .pageActionOpenPopup:
            handleOpenPopup(kind: .page, message: message, session: nil) { completion($0.map { _ in nil }) }
        case .openOptionsPage:
            handleOpenOptionsPage(message: message) { completion($0.map { _ in nil }) }
        case .newTab:
            handleNewTab(message: message) { completion($0.map { $0 as Any? }) }
        case .download:
            handleDownload(message: message) { completion($0.map { $0 as Any? }) }
        case .downloadComplete:
            handleDownloadComplete(message: message) { completion($0) }
        case .installPrompt:
            installPromptResponse(message: message) { completion($0.map { $0 as Any? }) }
        case .optionalPrompt:
            permissionPromptResponse(for: .optionalPrompt, message: message) { completion($0.map { $0 as Any? }) }
        case .updatePrompt:
            permissionPromptResponse(for: .updatePrompt, message: message) { completion($0.map { $0 as Any? }) }
        case .installationFailed:
            let failure = AddonInstallFailure(
                code: PayloadValue.string(message?["error"]),
                extensionID: PayloadValue.string(message?["addonId"]),
                extensionName: PayloadValue.string(message?["addonName"]),
                extensionVersion: PayloadValue.string(message?["addonVersion"])
            )
            delegate?.addonController(self, didFailInstall: failure)
            completion(.success(nil))
        case .uninstalled:
            if let removedAddon = removeAddon(from: message) {
                delegate?.addonController(self, didUpdate: removedAddon)
            }
            completion(.success(nil))
        case .optionalPermissionsChanged, .ready, .disabling, .disabled, .enabling, .enabled, .uninstalling, .installing, .installed:
            if let extensionDictionary = message?["extension"] as? [String: Any?] {
                let addon = upsertAddon(from: extensionDictionary)
                delegate?.addonController(self, didUpdate: addon)
            }
            completion(.success(nil))
        }
    }

    private func handleOpenOptionsPage(message: [String: Any?]?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let extensionID = message?["extensionId"] as? String else {
            completion(.failure(GeckoHandlerError("runtime.openOptionsPage is not supported")))
            return
        }
        addon(byID: extensionID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let addon):
                guard let addon else {
                    completion(.failure(GeckoHandlerError("runtime.openOptionsPage is not supported")))
                    return
                }
                self.delegate?.addonController(self, didRequestOpenOptionsPageFor: addon)
                completion(.success(()))
            }
        }
    }

    private func handleDownload(message: [String: Any?]?, completion: @escaping (Result<Any?, Error>) -> Void) {
        guard let extensionID = message?["extensionId"] as? String,
              let options = message?["options"] as? [String: Any?] else {
            completion(.failure(GeckoHandlerError("downloads.download is not supported")))
            return
        }
        addon(byID: extensionID) { [weak self] result in
            switch result {
            case .success(let addon):
                guard let self, let addon else {
                    completion(.failure(GeckoHandlerError("downloads.download is not supported")))
                    return
                }
                self.delegate?.addonController(self, didRequestDownload: options, for: addon) { response in
                    guard let response else {
                        completion(.failure(GeckoHandlerError("downloads.download is not supported")))
                        return
                    }
                    completion(.success(response))
                }
            case .failure:
                completion(.failure(GeckoHandlerError("downloads.download is not supported")))
            }
        }
    }

    private func handleDownloadComplete(message: [String: Any?]?, completion: @escaping (Result<Any?, Error>) -> Void) {
        guard let localFilePath = message?["localFilePath"] as? String else {
            completion(.failure(GeckoHandlerError("Invalid WebExtension download completion")))
            return
        }
        let succeeded = message?["succeeded"] as? Bool ?? false
        delegate?.addonController(self, didCompleteDownloadAt: localFilePath, succeeded: succeeded)
        completion(.success(nil))
    }

    private func handleNewTab(message: [String: Any?]?, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let extensionID = message?["extensionId"] as? String,
              let newSessionID = message?["newSessionId"] as? String else {
            completion(.success(false))
            return
        }
        addon(byID: extensionID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let addon):
                guard let addon else {
                    completion(.success(false))
                    return
                }
                let details = AddonCreateTabDetails(
                    dictionary: message?["createProperties"] as? [String: Any?] ?? [:]
                )
                completion(.success(self.delegate?.addonController(
                    self,
                    createNewTabFor: addon,
                    details: details,
                    newSessionID: newSessionID
                ) ?? false))
            }
        }
    }

    private func installPromptResponse(message: [String: Any?]?, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        permissionPrompt(for: .installPrompt, message: message) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let prompt):
                guard let prompt else {
                    completion(.success([
                        "allow": false,
                        "privateBrowsingAllowed": false,
                        "isTechnicalAndInteractionDataGranted": false,
                    ]))
                    return
                }
                let respond: (AddonPermissionPromptResponse) -> Void = { response in
                    completion(.success([
                        "allow": response.allow,
                        "privateBrowsingAllowed": response.privateBrowsingAllowed,
                        "isTechnicalAndInteractionDataGranted": response.technicalAndInteractionDataGranted,
                    ]))
                }
                guard let delegate = self.delegate else {
                    respond(.deny)
                    return
                }
                delegate.addonController(self, promptFor: prompt, completion: respond)
            }
        }
    }

    private func permissionPromptResponse(
        for event: AddonRuntimeEvent,
        message: [String: Any?]?,
        completion: @escaping (Result<[String: Bool], Error>) -> Void
    ) {
        permissionPrompt(for: event, message: message) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let prompt):
                guard let prompt else {
                    completion(.success(["allow": false]))
                    return
                }
                let respond: (AddonPermissionPromptResponse) -> Void = { response in
                    completion(.success(["allow": response.allow]))
                }
                guard let delegate = self.delegate else {
                    respond(.deny)
                    return
                }
                delegate.addonController(self, promptFor: prompt, completion: respond)
            }
        }
    }

    private func addonForPrompt(from message: [String: Any?]?, completion: @escaping (Result<Addon?, Error>) -> Void) {
        if let extensionDictionary = message?["extension"] as? [String: Any?] {
            completion(.success(Addon(dictionary: extensionDictionary)))
            return
        }

        guard let extensionID = addonID(from: message) else {
            completion(.success(nil))
            return
        }

        if let cachedAddon = addonsByID[extensionID] {
            completion(.success(cachedAddon))
            return
        }

        addon(byID: extensionID, completion: completion)
    }

    private func permissionPrompt(
        for event: AddonRuntimeEvent,
        message: [String: Any?]?,
        completion: @escaping (Result<AddonPermissionPrompt?, Error>) -> Void
    ) {
        addonForPrompt(from: message) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let addon):
                guard let addon else {
                    completion(.success(nil))
                    return
                }

                switch event {
                case .installPrompt:
                    completion(.success(AddonPermissionPrompt(
                        kind: .install,
                        addon: addon,
                        permissions: PayloadValue.strings(message?["permissions"]),
                        origins: PayloadValue.strings(message?["origins"]),
                        dataCollectionPermissions: PayloadValue.strings(message?["dataCollectionPermissions"])
                    )))
                case .optionalPrompt:
                    let permissionDictionary = message?["permissions"] as? [String: Any?]
                    completion(.success(AddonPermissionPrompt(
                        kind: .optional,
                        addon: addon,
                        permissions: PayloadValue.strings(permissionDictionary?["permissions"]),
                        origins: PayloadValue.strings(permissionDictionary?["origins"]),
                        dataCollectionPermissions: PayloadValue.strings(permissionDictionary?["data_collection"])
                    )))
                case .updatePrompt:
                    completion(.success(AddonPermissionPrompt(
                        kind: .update,
                        addon: addon,
                        permissions: PayloadValue.strings(message?["newPermissions"]),
                        origins: PayloadValue.strings(message?["newOrigins"]),
                        dataCollectionPermissions: PayloadValue.strings(message?["newDataCollectionPermissions"])
                    )))
                default:
                    completion(.success(nil))
                }
            }
        }
    }

    private func action(kind: AddonActionKind, from message: [String: Any?]?) -> AddonAction? {
        guard let dictionary = message?["action"] as? [String: Any?] else {
            return nil
        }
        return AddonAction(kind: kind, dictionary: dictionary)
    }

    private func handleActionUpdate(
        kind: AddonActionKind,
        message: [String: Any?]?,
        session: GeckoSession?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let extensionID = message?["extensionId"] as? String,
              let action = action(kind: kind, from: message) else {
            completion(.success(()))
            return
        }
        addon(byID: extensionID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let addon):
                guard let addon else {
                    completion(.success(()))
                    return
                }

                if session == nil {
                    if kind == .browser {
                        addon.browserAction = action
                    } else {
                        addon.pageAction = action
                    }
                }
                self.delegate?.addonController(self, didUpdate: action, for: addon, session: session)
                completion(.success(()))
            }
        }
    }

    private func handleOpenPopup(
        kind: AddonActionKind,
        message: [String: Any?]?,
        session: GeckoSession?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let extensionID = message?["extensionId"] as? String else {
            completion(.success(()))
            return
        }
        addon(byID: extensionID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let addon):
                guard let addon,
                      let action = self.action(kind: kind, from: message),
                      let popupURL = message?["popupUri"] as? String,
                      !popupURL.isEmpty else {
                    completion(.success(()))
                    return
                }
                self.delegate?.addonController(
                    self,
                    didRequestOpenPopup: popupURL,
                    for: addon,
                    action: action,
                    session: session
                )
                completion(.success(()))
            }
        }
    }
}
