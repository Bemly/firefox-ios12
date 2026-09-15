//
//  FrequentlyVisitedIconView.swift
//  Reynard
//
//  Created by Minh Ton on 24/6/26.
//

import UIKit

final class FrequentlyVisitedIconView: UIView {
    private enum UX {
        static let iconCornerRadius: CGFloat = 10
    }
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = .appSecondaryLabel
        view.layer.applyContinuousCornerCurve()
        view.layer.cornerRadius = UX.iconCornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var faviconLoader = HomepageFaviconLoader { [weak self] image, tintColor, _ in
        self?.applyIcon(image, tintColor: tintColor)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(url: URL) {
        faviconLoader.loadIcon(for: url)
    }
    
    private func configureView() {
        backgroundColor = .clear
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        faviconLoader.reset()
    }
    
    private func applyIcon(_ image: UIImage?, tintColor: UIColor?) {
        imageView.image = image
        imageView.tintColor = tintColor
    }
}
