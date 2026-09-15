//
//  AddonDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import Foundation

public struct AddonInstallFailure: Error {
    public let code: String?
    public let extensionID: String?
    public let extensionName: String?
    public let extensionVersion: String?
}

public protocol AddonEmbedderDelegate: AnyObject {
    func addonController(_ controller: AddonRuntime, didUpdate addon: Addon)
    func addonController(_ controller: AddonRuntime, didFailInstall failure: AddonInstallFailure)
    
    func addonController(_ controller: AddonRuntime, promptFor prompt: AddonPermissionPrompt, completion: @escaping (AddonPermissionPromptResponse) -> Void)
    func addonController(_ controller: AddonRuntime, didUpdate action: AddonAction, for addon: Addon, session: GeckoSession?)
    func addonController(_ controller: AddonRuntime, didRequestOpenPopup popupURL: String, for addon: Addon, action: AddonAction, session: GeckoSession?)
    func addonController(_ controller: AddonRuntime, didRequestOpenOptionsPageFor addon: Addon)
    func addonController(_ controller: AddonRuntime, didRequestDownload options: [String: Any?], for addon: Addon, completion: @escaping ([String: Any]?) -> Void)
    func addonController(_ controller: AddonRuntime, didCompleteDownloadAt localFilePath: String, succeeded: Bool)
    func addonController(_ controller: AddonRuntime, createNewTabFor addon: Addon, details: AddonCreateTabDetails, newSessionID: String) -> Bool
    func addonController(_ controller: AddonRuntime, updateTab session: GeckoSession, for addon: Addon, details: AddonUpdateTabDetails) -> AllowOrDeny
    func addonController(_ controller: AddonRuntime, closeTab session: GeckoSession, for addon: Addon) -> AllowOrDeny
}

public extension AddonEmbedderDelegate {
    func addonController(_ controller: AddonRuntime, didUpdate addon: Addon) {}
    func addonController(_ controller: AddonRuntime, didFailInstall failure: AddonInstallFailure) {}
    
    func addonController(_ controller: AddonRuntime, promptFor prompt: AddonPermissionPrompt, completion: @escaping (AddonPermissionPromptResponse) -> Void) { completion(.deny) }
    func addonController(_ controller: AddonRuntime, didUpdate action: AddonAction, for addon: Addon, session: GeckoSession?) {}
    func addonController(_ controller: AddonRuntime, didRequestOpenPopup popupURL: String, for addon: Addon, action: AddonAction, session: GeckoSession?) {}
    func addonController(_ controller: AddonRuntime, didRequestOpenOptionsPageFor addon: Addon) {}
    func addonController(_ controller: AddonRuntime, didRequestDownload options: [String: Any?], for addon: Addon, completion: @escaping ([String: Any]?) -> Void) { completion(nil) }
    func addonController(_ controller: AddonRuntime, didCompleteDownloadAt localFilePath: String, succeeded: Bool) {}
    func addonController(_ controller: AddonRuntime, createNewTabFor addon: Addon, details: AddonCreateTabDetails, newSessionID: String) -> Bool { false }
    func addonController(_ controller: AddonRuntime, updateTab session: GeckoSession, for addon: Addon, details: AddonUpdateTabDetails) -> AllowOrDeny { .deny }
    func addonController(_ controller: AddonRuntime, closeTab session: GeckoSession, for addon: Addon) -> AllowOrDeny { .deny }
}
