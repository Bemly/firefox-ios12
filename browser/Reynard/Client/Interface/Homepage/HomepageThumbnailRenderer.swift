//
//  HomepageThumbnailRenderer.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

final class HomepageThumbnailRenderer {
    private weak var homepageViewController: HomepageViewController?
    
    init(homepageViewController: HomepageViewController) {
        self.homepageViewController = homepageViewController
    }
    
    func prepareForCapture(contentMode: HomepageContentMode, isPrivateBrowsing: Bool) {
        guard let homepageViewController else {
            return
        }
        
        homepageViewController.loadViewIfNeeded()
        homepageViewController.setPrivateBrowsing(isPrivateBrowsing)
        homepageViewController.setContentMode(contentMode)
        homepageViewController.setShowsBackground(true)
        homepageViewController.view.setNeedsLayout()
        homepageViewController.view.layoutIfNeeded()
    }
    
    func capture(
        size: CGSize,
        visibleRect: CGRect,
        contentMode: HomepageContentMode,
        isPrivateBrowsing: Bool,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard size.width > 1,
              size.height > 1,
              visibleRect.width > 1,
              visibleRect.height > 1 else {
            completion(nil)
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            completion(self?.snapshot(
                size: size,
                visibleRect: visibleRect,
                contentMode: contentMode,
                isPrivateBrowsing: isPrivateBrowsing
            ))
        }
    }
    
    // TODO: This is slow and cause lags before tab overview presentation
    // animation or before address bar swipe animation.
    func snapshot(
        size: CGSize,
        visibleRect: CGRect,
        contentMode: HomepageContentMode,
        isPrivateBrowsing: Bool
    ) -> UIImage? {
        guard size.width > 1,
              size.height > 1,
              visibleRect.width > 1,
              visibleRect.height > 1,
              let homepageViewController else {
            return nil
        }
        
        homepageViewController.loadViewIfNeeded()
        homepageViewController.setPrivateBrowsing(isPrivateBrowsing)
        homepageViewController.setContentMode(contentMode)
        homepageViewController.setShowsBackground(true)
        homepageViewController.setVisibleContentInsets(visibleContentInsets(size: size, visibleRect: visibleRect))
        
        let view = homepageViewController.view!
        let originalFrame = view.frame
        let originalBounds = view.bounds
        let temporarilyAttachedView = view.superview == nil
        var captureContainer: UIView?
        if temporarilyAttachedView {
            captureContainer = UIView(frame: CGRect(origin: .zero, size: size))
            captureContainer?.addSubview(view)
            view.frame = captureContainer?.bounds ?? .zero
        } else {
            view.bounds.size = size
        }
        
        captureContainer?.layoutIfNeeded()
        view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: false)
        }
        
        if temporarilyAttachedView {
            view.removeFromSuperview()
        }
        view.bounds = originalBounds
        view.frame = originalFrame
        view.layoutIfNeeded()
        return image
    }
    
    private func visibleContentInsets(size: CGSize, visibleRect: CGRect) -> UIEdgeInsets {
        return UIEdgeInsets(
            top: max(0, visibleRect.minY),
            left: 0,
            bottom: max(0, size.height - visibleRect.maxY),
            right: 0
        )
    }
}
