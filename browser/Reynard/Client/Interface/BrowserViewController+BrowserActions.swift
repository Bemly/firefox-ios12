//
//  BrowserViewController+BrowserActions.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import UIKit

extension BrowserViewController {
    func presentShareSheet(
        items: [Any],
        sourceView: UIView,
        sourceRect: CGRect,
        completion: ((Bool, Error?) -> Void)? = nil
    ) {
        guard !items.isEmpty else {
            return
        }
        
        let activityController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceRect
        }
        if let completion {
            activityController.completionWithItemsHandler = { _, completed, _, error in
                completion(completed, error)
            }
        }
        present(activityController, animated: true)
    }
    
    func presentContentModal(_ rootViewController: UIViewController) {
        let navigationController = ContentModalNavigationController(
            rootViewController: rootViewController
        ) { [weak self] in
            self?.requestContentKeyboardFocus()
        }
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }
    
    func presentLibrary(
        initialSection: LibrarySection = .bookmarks,
        startsEditingBookmarks: Bool = false
    ) {
        if browserLayout.interfaceIdiom == .pad,
           browserLayout.chromeMode == .pad {
            sidebarCoordinator.showSection(
                initialSection,
                startsEditingBookmarks: startsEditingBookmarks
            )
            return
        }
        
        let libraryController = LibraryViewController(
            initialSection: initialSection,
            isPrivateMode: tabManager.selectedTab?.isPrivate == true,
            startsEditingBookmarks: startsEditingBookmarks,
            onClose: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        presentContentModal(libraryController)
    }
    
    func toggleLibrary(section: LibrarySection) {
        if browserLayout.interfaceIdiom == .pad,
           browserLayout.chromeMode == .pad {
            (splitViewController as? SidebarViewController)?.toggleSection(section)
            return
        }
        
        guard let navigationController = presentedViewController as? ContentModalNavigationController,
              let libraryController = navigationController.viewControllers.first as? LibraryViewController else {
            presentLibrary(initialSection: section)
            return
        }
        libraryController.toggleSection(section)
    }
    
    func createNewTab(mode: TabMode? = nil) {
        let targetMode = mode ?? (tabOverview.isPresented ? tabOverview.mode.tabMode : tabManager.selectedTabMode)
        toolbarController.reset()
        dismissAddressBarEditingAndOverlays()
        
        if tabOverview.isPresented {
            tabOverview.prepareNextTabChangesWithoutAnimation()
            createTabFromOverview(mode: targetMode)
        } else {
            homepageOverlayCoordinator.prepareHomepageForNewTab(mode: targetMode)
            let createdIndex = tabManager.createTab(selecting: true, mode: targetMode)
            applyNewTabDisplayOption(toTabAt: createdIndex)
            tabBar.setPendingExpansion(at: createdIndex)
            setTabOverviewVisible(false, animated: true)
        }
    }
    
    func closeAllTabs() {
        toolbarController.reset()
        dismissAddressBarEditingAndOverlays()
        let mode = tabManager.selectedTabMode
        let shouldCreateNewTab = mode == .regular && !tabManager.regularTabs.isEmpty
        tabManager.removeAllTabs(mode: mode)
        if shouldCreateNewTab {
            createNewTab(mode: .regular)
        }
    }
    
    func closeTab() {
        guard tabManager.selectedTab != nil else {
            return
        }
        
        let mode = tabManager.selectedTabMode
        closeTab(at: tabManager.selectedTabIndex, mode: mode)
        if mode == .regular && tabManager.regularTabs.isEmpty {
            createNewTab(mode: .regular)
        }
    }
    
    func createNewTabAnimated(mode: TabMode) {
        let sourceIndex = tabManager.selectedTabIndex
        let sourceMode = tabManager.selectedTabMode
        captureThumbnail(forTabAt: sourceIndex, mode: sourceMode) { [weak self] _ in
            guard let self else {
                return
            }
            
            self.toolbarController.reset()
            self.dismissAddressBarEditingAndOverlays()
            self.homepageOverlayCoordinator.prepareHomepageForNewTab(mode: mode)
            let target: TabInsertionTarget = self.tabManager.selectedTabMode == mode ? .afterSelected : .end
            let createdIndex = self.tabManager.createTab(
                selecting: false,
                target: target,
                mode: mode
            )
            let tabs = mode == .private ? self.tabManager.privateTabs : self.tabManager.regularTabs
            guard let tab = tabs[safe: createdIndex] else {
                return
            }
            
            self.prepareNewTab(tab, at: createdIndex, mode: mode) { [weak self] in
                guard let self else {
                    return
                }
                
                self.tabBar.setPendingExpansion(at: createdIndex)
                self.browserChrome.animateAutomaticNewTabTransition(to: tab) { [weak self] in
                    self?.tabManager.selectTab(at: createdIndex, mode: mode)
                }
            }
        }
    }
    
    private func prepareNewTab(
        _ tab: Tab,
        at index: Int,
        mode: TabMode,
        completion: @escaping () -> Void
    ) {
        switch Prefs.NewTabSettings.newTabDisplayOption {
        case .homepage, .blankPage:
            captureThumbnail(forTabAt: index, mode: mode) { _ in
                completion()
            }
        case .customURL:
            if URLUtils.isWebURL(Prefs.NewTabSettings.customNewTabURL) {
                tabManager.browse(to: Prefs.NewTabSettings.customNewTabURL, in: tab)
            }
            completion()
        }
    }
}
