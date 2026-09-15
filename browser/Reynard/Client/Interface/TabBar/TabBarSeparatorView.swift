//
//  TabBarSeparatorView.swift
//  Reynard
//
//  Created by Minh Ton on 14/8/26.
//

import UIKit

final class TabBarSeparatorView: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .separator
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
