//
//  AddressBarDismissButton.swift
//  Reynard
//
//  Created by Minh Ton on 10/6/26.
//

import UIKit

final class AddressBarDismissButton: UIButton {
    private enum UX {
        static let dismissButtonCornerRadiusDivisor: CGFloat = 2
        // PERF flat-chrome: dismiss-button shadow removed for compositing test.
        static let dismissButtonShadowOpacity: Float = 0
        static let dismissButtonDarkModeShadowAlpha: CGFloat = 0.3
        static let dismissButtonShadowRadius: CGFloat = 12
        static let dismissButtonShadowOffset = CGSize(width: 0, height: 4)
        static let dismissButtonSymbolPointSize: CGFloat = 20
        static let dismissButtonBorderWidth: CGFloat = 0.5
    }
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // PERF flat-chrome: rounded corners + shadow removed.
        layer.shadowOpacity = 0
        layer.cornerRadius = 0
        layer.shadowPath = nil
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else {
            return
        }
        
        updateBorderColor()
    }
    
    // MARK: - Appearance
    
    private func configureAppearance() {
        translatesAutoresizingMaskIntoConstraints = false
        alpha = 0
        isHidden = true
        let backgroundColor: UIColor
        if #available(iOS 13.0, *) {
            backgroundColor = UIColor.appDynamic { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .appTertiarySystemBackground : .appSystemBackground
            }
        } else {
            backgroundColor = .appSystemBackground
        }
        tintColor = .appLabel
        layer.applyContinuousCornerCurve()
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = UX.dismissButtonShadowRadius
        layer.shadowOffset = UX.dismissButtonShadowOffset
        layer.masksToBounds = false
        layer.borderWidth = UX.dismissButtonBorderWidth
        updateBorderColor()
        setImage(UIImage(named: "reynard.xmark"), for: .normal)
        if #available(iOS 13.0, *) {
            setPreferredSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: UX.dismissButtonSymbolPointSize, weight: .regular),
                forImageIn: .normal
            )
        }
    }
    
    private func updateBorderColor() {
        layer.borderColor = UIColor.appSeparator.withAlphaComponent(0.2).cgColor
    }
}
