//
//  UIImage+Symbol.swift
//  Reynard
//
//  iOS 12 compatibility shim for SF Symbols (UIImage(systemName:) is iOS 13+).
//  On iOS 12 there are no SF Symbols, so this returns nil (the image simply
//  does not appear). PoC behavior — real bundled-asset fallbacks are TODO.
//  见 AGENTS.md“iOS 12 兼容门禁清单” section 3.
//

import UIKit

extension UIImage {
    /// `UIImage(systemName:)` on iOS 13+, `nil` on iOS 12.
    static func appSymbol(_ systemName: String) -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: systemName)
        }
        return nil
    }
}
