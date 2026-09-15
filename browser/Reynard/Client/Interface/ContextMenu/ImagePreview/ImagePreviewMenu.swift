//
//  ImagePreviewMenu.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import UIKit

@available(iOS 13.0, *)
struct ImagePreviewMenu {
    static func configuration(
        for context: ContextMenuContext,
        showsPreview: Bool,
        isPrivate: Bool,
        sourceView: UIView,
        shareImage: @escaping (UIImage, UIView, CGRect) -> Void,
        openLinkInNewTab: @escaping (URL) -> Void,
        openLinkInNewPrivateTab: @escaping (URL) -> Void,
        openImageInNewTab: @escaping () -> Void
    ) -> UIContextMenuConfiguration? {
        guard case let .image(url, linkURL) = context.target else {
            return nil
        }
        
        let previewProvider: UIContextMenuContentPreviewProvider? = showsPreview ? {
            ImagePreviewViewController(url: url)
        } : nil
        
        return UIContextMenuConfiguration(identifier: UUID().uuidString as NSString, previewProvider: previewProvider) { _ in
            var children: [UIMenuElement] = []
            if let linkURL {
                var linkActions: [UIMenuElement] = [
                    UIAction(title: NSLocalizedString("Open Link in New Tab", comment: ""), image: UIImage(named: "reynard.plus.square.on.square")) { _ in
                        openLinkInNewTab(linkURL)
                    },
                ]
                if !isPrivate {
                    linkActions.append(
                        UIAction(title: NSLocalizedString("Open Link in New Private Tab", comment: ""), image: UIImage(named: "reynard.plus.square.fill.on.square.fill")) { _ in
                            openLinkInNewPrivateTab(linkURL)
                        }
                    )
                }
                children.append(
                    UIMenu(title: "", options: .displayInline, children: linkActions)
                )
            }
            
            children.append(
                UIMenu(title: "", options: .displayInline, children: [
                    UIAction(title: NSLocalizedString("Open Image in New Tab", comment: ""), image: UIImage(named: "reynard.plus.square.on.square")) { _ in
                        openImageInNewTab()
                    },
                    UIAction(title: NSLocalizedString("Share Image", comment: ""), image: UIImage(named: "reynard.square.and.arrow.up")) { _ in
                        loadImage(from: url) { image in
                            shareImage(
                                image,
                                sourceView,
                                CGRect(origin: context.point, size: .zero)
                            )
                        }
                    },
                    UIAction(title: NSLocalizedString("Save to Photos", comment: ""), image: UIImage(named: "reynard.square.and.arrow.down")) { _ in
                        loadImage(from: url) { image in
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        }
                    },
                    UIAction(title: NSLocalizedString("Copy Image", comment: ""), image: UIImage(named: "reynard.document.on.document")) { _ in
                        loadImage(from: url) { image in
                            UIPasteboard.general.image = image
                        }
                    },
                    UIAction(title: NSLocalizedString("Copy Image Address", comment: ""), image: UIImage(named: "reynard.document.on.document")) { _ in
                        UIPasteboard.general.string = url.absoluteString
                    },
                ])
            )
            
            return UIMenu(title: "", children: children)
        }
    }
    
    private static func loadImage(from url: URL, completion: @escaping (UIImage) -> Void) {
        ImagePreviewLoader.image(from: url) { image in
            guard let image else {
                return
            }
            completion(image)
        }
    }
    
}
