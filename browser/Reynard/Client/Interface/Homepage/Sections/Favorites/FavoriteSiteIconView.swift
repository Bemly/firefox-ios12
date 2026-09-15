//
//  FavoriteSiteIconView.swift
//  Reynard
//
//  Created by Minh Ton on 22/6/26.
//

import UIKit

final class FavoriteSiteIconView: UIView {
    private enum UX {
        static let transparentIconInset: CGFloat = 6
    }
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = .appSecondaryLabel
        return view
    }()
    
    private lazy var faviconLoader = HomepageFaviconLoader { [weak self] image, tintColor, shouldInset in
        self?.applyIcon(image, tintColor: tintColor, shouldInset: shouldInset)
    }
    private var imageConstraints: [NSLayoutConstraint] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(bookmark: BookmarkSnapshot) {
        faviconLoader.loadIcon(for: bookmark.url)
    }
    
    func reset() {
        faviconLoader.reset()
    }
    
    private func configureView() {
        backgroundColor = .clear
        addSubview(imageView)
        
        imageConstraints = [
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(imageConstraints)
        
        faviconLoader.reset()
    }
    
    private func applyIcon(_ image: UIImage?, tintColor: UIColor?, shouldInset: Bool) {
        imageView.image = image
        imageView.tintColor = tintColor
        let inset = shouldInset ? UX.transparentIconInset : 0
        imageConstraints[0].constant = inset
        imageConstraints[1].constant = -inset
        imageConstraints[2].constant = inset
        imageConstraints[3].constant = -inset
    }
}
