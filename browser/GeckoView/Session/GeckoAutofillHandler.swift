//
//  GeckoAutofillHandler.swift
//  Reynard
//
//  Created by Minh Ton on 14/7/26.
//

import UIKit

private enum CredentialEvent: String, CaseIterable {
    case start = "GeckoView:StartAutofill"
    case add = "GeckoView:AddAutofill"
    case focus = "GeckoView:OnAutofillFocus"
    case clear = "GeckoView:ClearAutofill"
}

private struct CredentialField {
    let uuid: String
    let formUuid: String?
    let credentialRole: String
    let isOneTimeCode: Bool
    let origin: String?
    
    init?(_ payload: [String: Any?]) {
        guard let uuid = payload["uuid"] as? String else {
            return nil
        }
        self.uuid = uuid
        formUuid = payload["rootUuid"] as? String
        credentialRole = payload["credentialRole"] as? String ?? ""
        isOneTimeCode = PayloadValue.bool(
            payload["isOneTimeCode"] ?? nil
        ) ?? false
        origin = payload["origin"] as? String
    }
}

private struct CredentialForm {
    let uuid: String
    let acceptsLoginCredentials: Bool
    let fields: [String: CredentialField]
    
    init?(_ payload: [String: Any?]) {
        guard let uuid = payload["uuid"] as? String else {
            return nil
        }
        self.uuid = uuid
        acceptsLoginCredentials = PayloadValue.bool(
            payload["acceptsLoginCredentials"] ?? nil
        ) ?? false
        
        var fields: [String: CredentialField] = [:]
        if let children = payload["children"] as? [Any] {
            for child in children {
                guard let fieldPayload = child as? [String: Any?],
                      let field = CredentialField(fieldPayload) else {
                    continue
                }
                fields[field.uuid] = field
            }
        }
        self.fields = fields
    }
}

final class GeckoAutofillHandler: NSObject, GeckoSessionHandlerCommon {
    let moduleName: String? = "GeckoViewAutofill"
    let events = CredentialEvent.allCases.map(\.rawValue)
    let enabled = true
    
    private weak var session: GeckoSession?
    private var credentialForms: [String: CredentialForm] = [:]
    private var focusedField: CredentialField?
    private var autofillSessionId: String?
    private var fillContinuations: [String: CheckedContinuation<Any?, Never>] = [:]
    
    init(session: GeckoSession) {
        self.session = session
    }
    
    @MainActor
    func handleMessage(type: String, message: [String: Any?]?) async throws -> Any? {
        guard let event = CredentialEvent(rawValue: type) else {
            throw GeckoHandlerError("unknown message \(type)")
        }
        
        switch event {
        case .start:
            clearState(refreshSuggestions: true)
            autofillSessionId = message?["sessionId"] as? String
            return nil
        case .clear:
            clearState(refreshSuggestions: true)
            autofillSessionId = nil
            return nil
        case .add:
            guard let formPayload = message?["node"] as? [String: Any?],
                  let form = CredentialForm(formPayload) else {
                return [:]
            }
            credentialForms[form.uuid] = form
            return await withCheckedContinuation {
                (continuation: CheckedContinuation<Any?, Never>) in
                // A refreshed form supersedes its older unresolved query.
                if let replacedContinuation = fillContinuations.updateValue(
                    continuation,
                    forKey: form.uuid
                ) {
                    replacedContinuation.resume(returning: [:])
                }
                if focusedField?.formUuid == form.uuid {
                    refreshAutofillSuggestions()
                }
            }
        case .focus:
            let hadActiveAutofillFocus = hasActiveAutofillFocus()
            let previousFieldUuid = focusedField?.uuid
            let wasFirstResponder = session?.engineView?.isFirstResponder == true
            if let fieldPayload = message?["node"] as? [String: Any?],
               let field = CredentialField(fieldPayload) {
                focusedField = field
                activatePasswordInputForAutofill()
            } else {
                focusedField = nil
            }
            let hasAutofillFocus = hasActiveAutofillFocus()
            let isGeometryRefresh = focusedField?.uuid == previousFieldUuid
            if !isGeometryRefresh {
                if focusedField == nil && hadActiveAutofillFocus {
                    discardTextInputDocument()
                }
                if !hadActiveAutofillFocus,
                   hasAutofillFocus,
                   let view = session?.engineView,
                   view.isFirstResponder {
                    if wasFirstResponder {
                        discardTextInputDocument()
                        view.resignFirstResponder()
                        view.becomeFirstResponder()
                    }
                } else if hadActiveAutofillFocus || hasAutofillFocus {
                    refreshAutofillSuggestions()
                }
            }
            return nil
        }
    }
    
    // Call to GeckoEditableSupport.mm
    func attach(to view: UIView) {
        let selector = NSSelectorFromString("setAutofillDelegate:")
        guard view.responds(to: selector) else {
            fatalError("Unimplemented")
        }
        view.perform(selector, with: self)
    }
    
    func detach(from view: UIView) {
        let selector = NSSelectorFromString("setAutofillDelegate:")
        guard view.responds(to: selector) else {
            fatalError("Unimplemented")
        }
        view.perform(selector, with: nil)
    }
    
    func close() {
        clearState(refreshSuggestions: false)
        autofillSessionId = nil
    }
    
    @objc(autofillTextContentType)
    func autofillTextContentType() -> UITextContentType? {
        guard let focusedField else {
            return nil
        }
        if focusedField.isOneTimeCode {
            return .oneTimeCode
        }
        guard acceptsLoginCredentials() else {
            return nil
        }
        switch focusedField.credentialRole {
        case "username":
            return .username
        case "password", "current-password":
            return .password
        default:
            return nil
        }
    }
    
    @objc(autofillOrigin)
    func autofillOrigin() -> String? {
        guard hasActiveAutofillFocus() else {
            return nil
        }
        return focusedField?.origin
    }
    
    @objc(acceptsLoginCredentials)
    func acceptsLoginCredentials() -> Bool {
        guard let focusedField,
              let formUuid = focusedField.formUuid,
              let form = credentialForms[formUuid],
              form.acceptsLoginCredentials,
              fillContinuations[formUuid] != nil else {
            return false
        }
        return ["username", "password", "current-password"].contains(
            focusedField.credentialRole
        )
    }
    
    @objc(didSelectAutofillUsername:password:)
    func didSelectAutofillUsername(_ username: String?, password: String?) {
        guard acceptsLoginCredentials(),
              let formUuid = focusedField?.formUuid,
              let form = credentialForms[formUuid],
              let fillContinuation = fillContinuations.removeValue(
                forKey: formUuid
              ) else {
            return
        }
        
        var valuesByField: [String: String] = [:]
        if let username, !username.isEmpty,
           let field = form.fields.values.first(where: {
               $0.credentialRole == "username"
           }) {
            valuesByField[field.uuid] = username
        }
        if let password, !password.isEmpty {
            let field = form.fields.values.first(where: {
                $0.credentialRole == "current-password"
            }) ?? form.fields.values.first(where: {
                $0.credentialRole == "password"
            })
            if let field {
                valuesByField[field.uuid] = password
            }
        }
        
        credentialForms.removeValue(forKey: formUuid)
        fillContinuation.resume(returning: valuesByField)
        if focusedField?.formUuid == formUuid {
            refreshAutofillSuggestions()
        }
    }
    
    @objc(didSelectOneTimeCode:)
    func didSelectOneTimeCode(_ value: String) {
        guard let session,
              let sessionId = autofillSessionId,
              let field = focusedField,
              field.isOneTimeCode,
              !value.isEmpty else {
            return
        }
        Task { @MainActor in
            _ = try? await session.dispatcher.query(
                type: "GeckoView:Autofill:FillOneTimeCode",
                message: [
                    "sessionId": sessionId,
                    "fieldUuid": field.uuid,
                    "value": value,
                ]
            )
        }
    }
    
    private func clearState(refreshSuggestions shouldRefresh: Bool) {
        let hadActiveAutofillFocus = hasActiveAutofillFocus()
        let continuations = Array(fillContinuations.values)
        fillContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(returning: [:])
        }
        credentialForms.removeAll()
        focusedField = nil
        if shouldRefresh && hadActiveAutofillFocus {
            refreshAutofillSuggestions()
        }
    }
    
    private func hasActiveAutofillFocus() -> Bool {
        return focusedField?.isOneTimeCode == true || acceptsLoginCredentials()
    }
    
    private func refreshAutofillSuggestions() {
        session?.engineView?.reloadInputViews()
    }
    
    
    // Call to GeckoEditableSupport.mm
    // Mirror WebKit's focus-transition teardown in WKContentView _hideKeyboard,
    // that UIKit must discard the previous text-input document before it queries
    // the new field's content type and private AutoFill context.
    private func discardTextInputDocument() {
        guard let view = session?.engineView else {
            return
        }
        let selector = NSSelectorFromString("setInputDelegate:")
        guard view.responds(to: selector) else {
            fatalError("Unimplemented")
        }
        view.perform(selector, with: nil)
    }
    
    
    // Call to GeckoEditableSupport.mm
    private func activatePasswordInputForAutofill() {
        guard let view = session?.engineView else {
            return
        }
        let selector = NSSelectorFromString("activatePasswordInputForAutofill")
        guard view.responds(to: selector) else {
            fatalError("Unimplemented")
        }
        view.perform(selector)
    }
}
