//
//  AddressBarMenu.swift
//  Reynard
//
//  Created by Minh Ton on 28/4/26.
//

import UIKit

enum AddressBarMenu {
    private enum UX {
        static let audioTabFaviconSize = CGSize(width: 20, height: 20)
    }
    
    @available(iOS 13.0, *)
    private struct Identifier {
        static let addressBarMenu = UIMenu.Identifier("moe.bemly.reynard.AddressBarMenu")
        static let manageAddonsMenu = UIMenu.Identifier("moe.bemly.reynard.AddressBarMenu.ManageAddons")
    }
    
    struct AddonItem {
        let menuItem: AddonMenuItem
        let image: UIImage?
    }
    
    enum AudioAction {
        case selectTab(UUID)
        case setMuted(tabID: UUID, muted: Bool)
        case muteOtherTabs(excluding: UUID)
    }
    
    struct AudioTabItem {
        let id: UUID
        let title: String
        let favicon: UIImage?
        let isMuted: Bool
    }
    
    struct AudioState {
        let playingTabs: [AudioTabItem]
        let selectedTabID: UUID?
        let isSelectedTabMuted: Bool
        
        var canMuteSelectedTab: Bool {
            guard let selectedTabID else { return false }
            return isSelectedTabMuted || playingTabs.contains { $0.id == selectedTabID }
        }
        
        var canMuteOtherTabs: Bool {
            guard let selectedTabID else { return false }
            return playingTabs.contains { $0.id != selectedTabID && !$0.isMuted }
        }
    }
    
    @available(iOS 13.0, *)
    static func makeMenu(
        selectedURL: String?,
        usesDesktopWebsite: Bool?,
        addonItems: [AddonItem],
        isReaderable: Bool,
        onShowReader: @escaping () -> Void,
        onAddonSelected: @escaping (AddonMenuItem) -> Void,
        onFindInPage: @escaping () -> Void,
        onPageZoom: @escaping () -> Void,
        onChangeWebsiteMode: @escaping () -> Void,
        onHideToolbar: @escaping () -> Void,
        onWebsiteSettings: @escaping () -> Void,
        onBookmark: @escaping (Bool) -> Void
    ) -> UIMenu {
        var tabActions: [UIMenuElement] = []
        
        let url = selectedURL.flatMap(URL.init(string:))
        if let url, url.host != nil {
            let title = BookmarkStore.shared.bookmark(savedFor: url) == nil ? NSLocalizedString("Add Bookmark", comment: "") : NSLocalizedString("Edit Bookmark", comment: "")
            tabActions.append(UIAction(title: title, image: UIImage(named: "reynard.book")) { _ in
                onBookmark(false)
            })
            
            if !BookmarkStore.shared.isSavedInFavorites(url) {
                tabActions.append(UIAction(title: NSLocalizedString("Add to Favorites", comment: ""), image: UIImage(named: "reynard.star")) { _ in
                    onBookmark(true)
                })
            }
        }
        
        let addonsChildren: [UIMenuElement]
        if addonItems.isEmpty {
            addonsChildren = [
                UIAction(
                    title: NSLocalizedString("No Add-ons", comment: ""),
                    image: UIImage(named: "reynard.puzzlepiece.extension"),
                    attributes: .disabled
                ) { _ in }
            ]
        } else {
            addonsChildren = addonItems.map { item in
                UIAction(title: item.menuItem.title, image: item.image) { _ in
                    onAddonSelected(item.menuItem)
                }
            }
        }
        
        var pageActions: [UIMenuElement] = [
            UIMenu(
                title: NSLocalizedString("Add-ons", comment: ""),
                image: UIImage(named: "reynard.puzzlepiece.extension"),
                identifier: Identifier.manageAddonsMenu,
                children: addonsChildren
            )
        ]
        
        if url?.host != nil {
            pageActions.append(UIAction(title: NSLocalizedString("Page Zoom", comment: ""), image: UIImage(named: "reynard.textformat.size")) { _ in
                onPageZoom()
            })
            if isReaderable {
                pageActions.append(UIAction(title: NSLocalizedString("Show Reader", comment: ""), image: UIImage(named: "reynard.text.page")) { _ in
                    onShowReader()
                })
            }
            pageActions.append(UIAction(title: NSLocalizedString("Find in Page", comment: ""), image: UIImage(named: "reynard.text.page.badge.magnifyingglass")) { _ in
                onFindInPage()
            })
        }
        
        if let isDesktop = usesDesktopWebsite {
            let title = isDesktop ? NSLocalizedString("Request Mobile Website", comment: "") : NSLocalizedString("Request Desktop Website", comment: "")
            let imageName = isDesktop ? "reynard.smartphone" : "reynard.desktopcomputer"
            pageActions.append(UIAction(title: title, image: UIImage(named: imageName)) { _ in
                onChangeWebsiteMode()
            })
        }
        
        var settingsActions: [UIMenuElement] = [
            UIAction(title: NSLocalizedString("Hide Toolbar", comment: ""), image: UIImage(named: "reynard.arrow.up.left.and.arrow.down.right")) { _ in
                onHideToolbar()
            }
        ]
        if url?.host != nil {
            settingsActions.append(UIAction(title: NSLocalizedString("Website Settings", comment: ""), image: UIImage(named: "reynard.gear")) { _ in
                onWebsiteSettings()
            })
        }
        
        let children = tabActions + [UIMenu(options: .displayInline, children: pageActions)] + [UIMenu(options: .displayInline, children: settingsActions)]
        
        return UIMenu(title: "", image: nil, identifier: Identifier.addressBarMenu, options: [], children: children)
    }
    
    @available(iOS 13.0, *)
    static func makeAudioMenu(
        state: AudioState,
        onAction: @escaping (AudioAction) -> Void
    ) -> UIMenu {
        var audioActions: [UIMenuElement] = []
        if state.canMuteSelectedTab,
           let selectedTabID = state.selectedTabID {
            let muteImageName = state.isSelectedTabMuted
            ? "reynard.speaker.wave.2.fill"
            : "reynard.speaker.slash.fill"
            audioActions.append(
                UIAction(
                    title: state.isSelectedTabMuted
                    ? NSLocalizedString("Unmute This Tab", comment: "")
                    : NSLocalizedString("Mute This Tab", comment: ""),
                    image: UIImage(named: muteImageName)
                ) { _ in
                    onAction(.setMuted(tabID: selectedTabID, muted: !state.isSelectedTabMuted))
                }
            )
        }
        if state.canMuteOtherTabs,
           let selectedTabID = state.selectedTabID {
            audioActions.append(
                UIAction(
                    title: NSLocalizedString("Mute Other Tabs", comment: ""),
                    image: UIImage(named: "reynard.speaker.slash.fill")
                ) { _ in
                    onAction(.muteOtherTabs(excluding: selectedTabID))
                }
            )
        }
        
        let tabActions = state.playingTabs.map { tab in
            let favicon = tab.favicon.map { image in
                UIGraphicsImageRenderer(size: UX.audioTabFaviconSize).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: UX.audioTabFaviconSize))
                }
            }
            return UIAction(title: tab.title, image: favicon) { _ in
                onAction(.selectTab(tab.id))
            }
        }
        var children: [UIMenuElement] = []
        if !audioActions.isEmpty {
            children.append(UIMenu(options: .displayInline, children: audioActions))
        }
        children.append(
            UIMenu(
                title: NSLocalizedString("Tabs with Sound", comment: ""),
                options: .displayInline,
                children: tabActions
            )
        )
        return UIMenu(title: "", children: children)
    }
}
