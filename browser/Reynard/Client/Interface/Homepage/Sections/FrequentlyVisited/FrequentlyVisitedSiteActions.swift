//
//  FrequentlyVisitedSiteActions.swift
//  Reynard
//
//  Created by Minh Ton on 27/6/26.
//

import UIKit

@available(iOS 13.0, *)
struct FrequentlyVisitedSiteActions {
    static func configuration(
        for site: HistorySiteSnapshot,
        openInNewTab: @escaping () -> Void,
        openInNewPrivateTab: @escaping () -> Void,
        shareLink: @escaping (URL) -> Void,
        removeLink: @escaping () -> Void
    ) -> UIContextMenuConfiguration {
        return UIContextMenuConfiguration(identifier: site.url as NSURL, previewProvider: nil) { _ in
            UIMenu(title: "", children: [
                UIMenu(title: "", options: .displayInline, children: [
                    UIAction(title: NSLocalizedString("Open in New Tab", comment: ""), image: UIImage(named: "reynard.plus.square.on.square")) { _ in
                        openInNewTab()
                    },
                    UIAction(title: NSLocalizedString("Open in New Private Tab", comment: ""), image: UIImage(named: "reynard.plus.square.fill.on.square.fill")) { _ in
                        openInNewPrivateTab()
                    },
                ]),
                UIMenu(title: "", options: .displayInline, children: [
                    UIAction(title: NSLocalizedString("Copy Link", comment: ""), image: UIImage(named: "reynard.document.on.document")) { _ in
                        UIPasteboard.general.string = site.url.absoluteString
                    },
                    UIAction(title: NSLocalizedString("Share Link", comment: ""), image: UIImage(named: "reynard.square.and.arrow.up")) { _ in
                        shareLink(site.url)
                    },
                ]),
                UIAction(title: NSLocalizedString("Remove Link", comment: ""), image: UIImage(named: "reynard.minus.circle"), attributes: .destructive) { _ in
                    removeLink()
                },
            ])
        }
    }
}

@available(iOS 13.0, *)
extension FrequentlyVisitedSectionViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let cardView = interaction.view as? FrequentlyVisitedSiteCardView,
              let site = site(for: cardView) else {
            return nil
        }
        
        return FrequentlyVisitedSiteActions.configuration(
            for: site,
            openInNewTab: { [weak self] in
                guard let self else {
                    return
                }
                
                self.delegate?.homepageSection(self, didRequestOpenURL: site.url, disposition: .newTab)
            },
            openInNewPrivateTab: { [weak self] in
                guard let self else {
                    return
                }
                
                self.delegate?.homepageSection(self, didRequestOpenURL: site.url, disposition: .newPrivateTab)
            },
            shareLink: { [weak self, weak cardView] url in
                guard let self,
                      let cardView else {
                    return
                }
                
                self.delegate?.homepageSection(
                    self,
                    didRequestShareURL: url,
                    sourceView: cardView
                )
            },
            removeLink: { [weak self] in
                guard let self else {
                    return
                }
                
                self.delegate?.homepageSection(self, didRequestHideFromSuggestions: site.id)
            }
        )
    }
}
