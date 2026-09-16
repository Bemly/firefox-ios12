//
//  UIApplication+Presentation.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import UIKit

extension UIApplication {
    /// The active key window. Resolved via scenes on iOS 13+, and via the
    /// `windows` array on iOS 12 (which has no scene support). 见 AGENTS.md“iOS 12 兼容门禁清单”.
    var appKeyWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: { $0.isKeyWindow })
        }
        return windows.first(where: { $0.isKeyWindow })
    }

    var isTwoThirdSplitScreenOrSmaller: Bool {
        guard let window = appKeyWindow else {
            return false
        }

        return isTwoThirdSplitScreenOrSmaller(forWindowWidth: window.bounds.width, screen: window.screen)
    }

    var isOneThirdSplitScreenOrSmaller: Bool {
        guard let window = appKeyWindow else {
            return false
        }

        return isOneThirdSplitScreenOrSmaller(forWindowWidth: window.bounds.width, screen: window.screen)
    }

    var isHalfSplitScreenOrSmaller: Bool {
        guard let window = appKeyWindow else {
            return false
        }

        return isHalfSplitScreenOrSmaller(forWindowWidth: window.bounds.width, screen: window.screen)
    }
    
    func isTwoThirdSplitScreenOrSmaller(forWindowWidth windowWidth: CGFloat, screen: UIScreen) -> Bool {
        let screenWidth = max(screen.bounds.width, screen.bounds.height)
        return windowWidth <= (3.0 / 4.0) * screenWidth + 0.5
    }
    
    func isOneThirdSplitScreenOrSmaller(forWindowWidth windowWidth: CGFloat, screen: UIScreen) -> Bool {
        let screenWidth = max(screen.bounds.width, screen.bounds.height)
        return windowWidth <= (2.0 / 5.0) * screenWidth + 0.5
    }
    
    func isHalfSplitScreenOrSmaller(forWindowWidth windowWidth: CGFloat, screen: UIScreen) -> Bool {
        let screenWidth = max(screen.bounds.width, screen.bounds.height)
        return windowWidth <= (3.0 / 5.0) * screenWidth + 0.5
    }
    
    func topViewController() -> UIViewController? {
        guard let rootViewController = appKeyWindow?.rootViewController else {
            return nil
        }

        return topViewController(from: rootViewController)
    }
    
    func topViewController(from rootViewController: UIViewController) -> UIViewController {
        var controller = rootViewController
        while let presentedController = controller.presentedViewController {
            controller = presentedController
        }
        return controller
    }
}
