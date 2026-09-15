//
//  BrowserViewController+Addons.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import GeckoView
import UIKit

extension BrowserViewController: AddonCoordinatorDataSource, AddonCoordinatorDelegate {
    // MARK: - AddonCoordinatorDataSource
    
    var selectedAddonSession: GeckoSession? {
        return tabManager.selectedTab?.session
    }
    
    var isSelectedAddonTabPrivate: Bool {
        return tabManager.selectedTab?.isPrivate == true
    }
    
    var addonTabs: [Tab] {
        return tabManager.activeTabs
    }
    
    var selectedAddonTabMode: TabMode {
        return tabManager.selectedTabMode
    }
    
    var shouldPresentAddonPopupAsPopover: Bool {
        return browserLayout.chromeMode == .pad
    }
    
    func indexOfAddonTab(for session: GeckoSession) -> Int? {
        return tabManager.tabIndex(for: session)
    }
    
    // MARK: - AddonCoordinatorDelegate
    
    func refreshAddonChrome(_ coordinator: AddonCoordinator) {
        refreshAddressBar()
    }
    
    func performAfterAddonMenuDismissal(_ coordinator: AddonCoordinator, work: @escaping () -> Void) {
        browserChrome.performAfterAddressBarMenuDismissal(work)
    }
    
    func presentAddonViewController(_ coordinator: AddonCoordinator, _ viewController: UIViewController) {
        let presentViewController = { [weak self] in
            guard let self else {
                return
            }
            UIApplication.shared.topViewController(from: self).present(viewController, animated: true)
        }
        
        if let popupViewController = viewController as? AddonPopupViewController,
           let popover = popupViewController.popoverPresentationController {
            toolbarController.lock(for: .addonPopover)
            let sourceButton = browserChrome.addressBarButton
            popover.sourceView = sourceButton
            popover.sourceRect = sourceButton.bounds
            popover.permittedArrowDirections = .up
            popover.delegate = popupViewController
            browserChrome.performAfterAddressBarMenuDismissal(presentViewController)
            return
        }
        
        presentViewController()
    }
    
    func presentAddonAlert(_ coordinator: AddonCoordinator, title: String?, message: String) {
        AlertPresenter.show(title: title, message: message)
    }
    
    func dismissAddonModal(_ coordinator: AddonCoordinator, completion: (() -> Void)?) -> Bool {
        let presenter = UIApplication.shared.topViewController(from: self)
        guard presenter !== self else {
            return false
        }
        
        presenter.dismiss(animated: true, completion: completion)
        return true
    }
    
    func createAddonTab(
        _ coordinator: AddonCoordinator,
        selecting: Bool,
        url: String?,
        windowId: String?,
        at index: Int?,
        loadImmediately: Bool
    ) -> Tab? {
        return tabManager.createRegularTab(
            selecting: selecting,
            windowId: windowId,
            target: index.map(TabInsertionTarget.index) ?? .end,
            url: url,
            loadImmediately: loadImmediately
        )
    }
    
    func selectAddonTab(_ coordinator: AddonCoordinator, at index: Int, mode: TabMode?) {
        tabManager.selectTab(at: index, mode: mode)
    }
    
    func closeAddonTab(_ coordinator: AddonCoordinator, at index: Int, mode: TabMode?) {
        tabManager.removeTab(at: index, mode: mode)
    }
    
    func confirmAddonDownload(
        _ coordinator: AddonCoordinator,
        options: [String: Any?],
        completion: @escaping (DownloadStore.WebExtensionDownloadItem?) -> Void
    ) {
        guard let pendingDownload = DownloadStore.shared.pendingDownload(
            from: options
        ) else {
            completion(nil)
            return
        }
        downloadsCoordinator.confirmWebExtensionDownload(pendingDownload, completion: completion)
    }
    
    func restoreAddonTabInteraction(_ coordinator: AddonCoordinator) {
        toolbarController.unlock(for: .addonPopover)
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let session = tabManager.selectedTab?.session else {
                return
            }
            
            contentView.restoreInteraction(for: session)
            sessionManager.activate(session)
            requestContentKeyboardFocus(for: session)
        }
    }
}
