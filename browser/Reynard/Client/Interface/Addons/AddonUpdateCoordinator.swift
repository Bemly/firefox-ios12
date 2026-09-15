//
//  AddonUpdateCoordinator.swift
//  Reynard
//
//  Created by Minh Ton on 24/5/26.
//

import GeckoView
import Foundation

struct AddonUpdateBatchResult {
    let updatedCount: Int
    let noUpdateCount: Int
    let pendingApprovalCount: Int
    let failedCount: Int
}

final class AddonUpdateCoordinator {
    private var shouldRunAutomaticCheck: Bool
    private var isRunningBatch = false
    private var shouldPresentUpdatePrompts = false
    private var isSettingsVisible = false
    
    init() {
        if let lastGlobalCheckAt = Prefs.AddonSettings.lastGlobalCheckAt {
            shouldRunAutomaticCheck = Date().timeIntervalSince(lastGlobalCheckAt) >= 12 * 60 * 60
        } else {
            shouldRunAutomaticCheck = true
        }
    }
    
    var hasPendingApprovals: Bool {
        return !Prefs.AddonSettings.pendingApprovalAddonIDs.isEmpty
    }
    
    func start() {
        prunePendingApprovals()
        guard shouldRunAutomaticCheck else {
            return
        }
        shouldRunAutomaticCheck = false
        runAutomaticCheck()
    }
    
    func setSettingsVisible(_ visible: Bool) {
        isSettingsVisible = visible
        if visible {
            prunePendingApprovals()
        }
    }
    
    
    func responseForUpdatePrompt(
        _ prompt: AddonPermissionPrompt,
        presentPrompt: @escaping (AddonPermissionPrompt, @escaping (AddonPermissionPromptResponse) -> Void) -> Void,
        completion: @escaping (AddonPermissionPromptResponse) -> Void
    ) {
        guard shouldPresentUpdatePrompts && isSettingsVisible else {
            markNeedsApproval(prompt.addon.id)
            completion(.deny)
            return
        }

        presentPrompt(prompt) { [weak self] response in
            guard let self else {
                completion(response)
                return
            }
            if response.allow {
                self.clearPendingApproval(prompt.addon.id)
            } else {
                self.markNeedsApproval(prompt.addon.id)
            }
            completion(response)
        }
    }

    func updateAllAddons(
        status: @escaping  (String, String?) -> Void,
        completion: @escaping (AddonUpdateBatchResult) -> Void
    ) {
        runUpdateBatch(
            addons: updateCandidates(),
            status: status,
            completion: completion
        )
    }

    func completePendingUpdates(
        status: @escaping  (String, String?) -> Void,
        completion: @escaping (AddonUpdateBatchResult) -> Void
    ) {
        let pendingIDs = Set(Prefs.AddonSettings.pendingApprovalAddonIDs)
        let addons = updateCandidates().filter { pendingIDs.contains($0.id) }
        runUpdateBatch(addons: addons, status: status, completion: completion)
    }

    private func runAutomaticCheck(completion: @escaping () -> Void = {}) {
        guard !isRunningBatch else {
            completion()
            return
        }

        isRunningBatch = true

        let candidates = updateCandidates()

        func finish() {
            isRunningBatch = false
            Prefs.AddonSettings.lastGlobalCheckAt = Date()
            completion()
        }

        func processNext(_ index: Int) {
            guard index < candidates.count else {
                finish()
                return
            }

            let addon = candidates[index]
            AddonRuntime.shared.update(addon) { result in
                switch result {
                case .success(let updatedAddon):
                    if updatedAddon == nil {
                        self.clearPendingApproval(addon.id)
                    }
                case .failure(let error):
                    if AddonErrorPresenter.updateRequiresPermissions(error) {
                        self.markNeedsApproval(addon.id)
                    }
                }
                processNext(index + 1)
            }
        }

        processNext(0)
    }

    private func runUpdateBatch(
        addons: [Addon],
        status: @escaping  (String, String?) -> Void,
        completion: @escaping (AddonUpdateBatchResult) -> Void
    ) {
        guard !isRunningBatch else {
            completion(AddonUpdateBatchResult(
                updatedCount: 0,
                noUpdateCount: 0,
                pendingApprovalCount: Prefs.AddonSettings.pendingApprovalAddonIDs.count,
                failedCount: 0
            ))
            return
        }

        isRunningBatch = true
        shouldPresentUpdatePrompts = true

        var updatedCount = 0
        var noUpdateCount = 0
        var failedCount = 0

        func finish() {
            shouldPresentUpdatePrompts = false
            isRunningBatch = false
            Prefs.AddonSettings.lastGlobalCheckAt = Date()
            completion(AddonUpdateBatchResult(
                updatedCount: updatedCount,
                noUpdateCount: noUpdateCount,
                pendingApprovalCount: Prefs.AddonSettings.pendingApprovalAddonIDs.count,
                failedCount: failedCount
            ))
        }

        func processNext(_ index: Int) {
            guard index < addons.count else {
                finish()
                return
            }

            let addon = addons[index]
            status(addon.id, NSLocalizedString("Updating…", comment: ""))

            AddonRuntime.shared.update(addon) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let updatedAddon):
                        if updatedAddon == nil {
                            noUpdateCount += 1
                            self.clearPendingApproval(addon.id)
                            status(addon.id, NSLocalizedString("No Update Available", comment: ""))
                        } else {
                            updatedCount += 1
                            self.clearPendingApproval(addon.id)
                            status(addon.id, NSLocalizedString("Updated", comment: ""))
                        }
                    case .failure(let error):
                        if AddonErrorPresenter.updateRequiresPermissions(error) {
                            self.markNeedsApproval(addon.id)
                            status(addon.id, NSLocalizedString("Needs Permission to Update", comment: ""))
                            processNext(index + 1)
                            return
                        }

                        failedCount += 1
                        let presentation = AddonErrorPresenter.updateErrorPresentation(
                            for: error,
                            addonName: addon.metaData.name ?? addon.id
                        )
                        status(addon.id, presentation.statusText)
                    }
                    processNext(index + 1)
                }
            }
        }

        processNext(0)
    }
    
    private func updateCandidates() -> [Addon] {
        prunePendingApprovals()
        return AddonRuntime.shared.installedAddons.filter {
            !$0.isBuiltIn && !$0.metaData.isUnsupported
        }
    }
    
    private func prunePendingApprovals() {
        let validAddonIDs = Set(AddonRuntime.shared.installedAddons.filter {
            !$0.isBuiltIn && !$0.metaData.isUnsupported
        }.map(\ .id))
        let filteredIDs = Prefs.AddonSettings.pendingApprovalAddonIDs.filter { validAddonIDs.contains($0) }
        if filteredIDs != Prefs.AddonSettings.pendingApprovalAddonIDs {
            Prefs.AddonSettings.pendingApprovalAddonIDs = filteredIDs
        }
    }
    
    private func markNeedsApproval(_ addonID: String) {
        var pendingApprovalAddonIDs = Prefs.AddonSettings.pendingApprovalAddonIDs
        if !pendingApprovalAddonIDs.contains(addonID) {
            pendingApprovalAddonIDs.append(addonID)
            Prefs.AddonSettings.pendingApprovalAddonIDs = pendingApprovalAddonIDs
        }
    }
    
    private func clearPendingApproval(_ addonID: String) {
        let filteredIDs = Prefs.AddonSettings.pendingApprovalAddonIDs.filter { $0 != addonID }
        if filteredIDs != Prefs.AddonSettings.pendingApprovalAddonIDs {
            Prefs.AddonSettings.pendingApprovalAddonIDs = filteredIDs
        }
    }
}
