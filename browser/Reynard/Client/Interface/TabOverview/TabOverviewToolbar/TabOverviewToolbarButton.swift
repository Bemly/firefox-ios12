//
//  TabOverviewToolbarButton.swift
//  Reynard
//
//  Created by Minh Ton on 10/6/26.
//

import UIKit

final class TabOverviewToolbarButton: UIButton {
    private enum UX {
        static let toolbarButtonSideLength: CGFloat = 42
        static let toolbarButtonCornerRadius: CGFloat = 21
        static let toolbarButtonBorderWidth: CGFloat = 1
        static let toolbarButtonSymbolPointSize: CGFloat = 17
        static let disabledToolbarButtonAlpha: CGFloat = 0.35
    }
    
    enum Action {
        case clear
        case add
        case done
    }
    
    private let action: Action
    private var legacyMenuDelegate: AnyObject?
    
    init(action: Action) {
        self.action = action
        super.init(frame: .zero)
        if #available(iOS 13.4, *) {
            isPointerInteractionEnabled = true
        }
        configureAppearance()
        configureImage()
        configureConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setActionEnabled(_ enabled: Bool) {
        isEnabled = enabled
        alpha = enabled ? 1 : UX.disabledToolbarButtonAlpha
    }
    
    @available(iOS 13.0, *)
    func installMenu(_ menu: UIMenu?) {
        if #available(iOS 14.0, *) {
            self.menu = menu
            showsMenuAsPrimaryAction = menu != nil
        } else {
            if legacyMenuDelegate == nil {
                let delegate = LegacyMenuDelegate()
                addInteraction(UIContextMenuInteraction(delegate: delegate))
                addTarget(self, action: #selector(presentLegacyMenu), for: .touchUpInside)
                legacyMenuDelegate = delegate
            }
            (legacyMenuDelegate as? LegacyMenuDelegate)?.menu = menu
        }
    }
    
    private func configureAppearance() {
        translatesAutoresizingMaskIntoConstraints = false
        tintColor = action == .done ? .appSystemBackground : .appLabel
        backgroundColor = action == .done ? .appLabel : .appQuaternarySystemFill
        layer.borderWidth = action == .done ? 0 : UX.toolbarButtonBorderWidth
        layer.borderColor = action == .done ? UIColor.clear.cgColor : UIColor.appSystemFill.cgColor
        layer.applyContinuousCornerCurve()
        layer.cornerRadius = UX.toolbarButtonCornerRadius
    }
    
    private func configureImage() {
        setImage(UIImage(named: symbolName), for: .normal)
        if #available(iOS 13.0, *) {
            setPreferredSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: UX.toolbarButtonSymbolPointSize, weight: .regular),
                forImageIn: .normal
            )
        }
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: UX.toolbarButtonSideLength),
            heightAnchor.constraint(equalTo: widthAnchor),
        ])
    }
    
    private var symbolName: String {
        switch action {
        case .clear: return "reynard.trash"
        case .add: return "reynard.plus"
        case .done: return "reynard.checkmark"
        }
    }
    
    @available(iOS 13.0, *)
    @objc private func presentLegacyMenu() {
        guard let interaction = interactions.compactMap({ $0 as? UIContextMenuInteraction }).first else {
            return
        }
        
        let selector = NSSelectorFromString("_presentMenuAtLocation:")
        guard interaction.responds(to: selector) else {
            return
        }
        
        let center = NSValue(cgPoint: CGPoint(x: bounds.midX, y: bounds.midY))
        _ = interaction.perform(selector, with: center)
    }
}

@available(iOS 13.0, *)
private final class LegacyMenuDelegate: NSObject, UIContextMenuInteractionDelegate {
    var menu: UIMenu?
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let menu else {
            return nil
        }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            menu
        }
    }
}
