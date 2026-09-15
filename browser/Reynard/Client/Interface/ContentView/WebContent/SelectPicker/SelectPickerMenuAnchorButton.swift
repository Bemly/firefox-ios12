//
//  SelectPickerMenuAnchorButton.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import UIKit

final class SelectPickerMenuAnchorButton: UIButton {
    // MARK: - State
    
    var onMenuWillDismiss: (() -> Void)?
    var onMenuDismissed: (() -> Void)?
    
    // MARK: - Overrides
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return false
    }
    
    @available(iOS 14.0, *)
    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        onMenuWillDismiss?()
        let handler = onMenuDismissed
        if let animator {
            animator.addCompletion {
                handler?()
            }
        } else {
            handler?()
        }
    }
}
