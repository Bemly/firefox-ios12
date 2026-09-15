//
//  FavoriteSiteCollectionViewCell.swift
//  Reynard
//
//  Created by Minh Ton on 22/6/26.
//

import UIKit

final class FavoriteSiteCollectionViewCell: UICollectionViewCell {
    private enum UX {
        static let maximumIconSize: CGFloat = 74
        static let iconCornerRadius: CGFloat = 17
        static let titleHeight: CGFloat = 34
        static let titleFontSize: CGFloat = 12
        static let shadowOpacity: Float = 0.18
        static let shadowRadius: CGFloat = 5
        static let shadowOffsetWidth: CGFloat = 0
        static let shadowOffsetHeight: CGFloat = 2
        static let reorderLiftedOutset: CGFloat = 4
        static let reorderLiftAnimationDuration: TimeInterval = 0.18
    }
    
    enum ReorderState {
        case resting
        case lifted
    }
    
    static let reuseIdentifier = "FavoriteSiteCollectionViewCell"
    
    var contextMenuAnchorView: UIView {
        return iconBackgroundView
    }
    
    private static let titleFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .semibold)
    )
    
    private let shadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.clipsToBounds = false
        view.layer.shadowOpacity = UX.shadowOpacity
        view.layer.shadowRadius = UX.shadowRadius
        view.layer.shadowOffset = CGSize(width: UX.shadowOffsetWidth, height: UX.shadowOffsetHeight)
        return view
    }()
    
    private let iconBackgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.applyContinuousCornerCurve()
        view.layer.cornerRadius = UX.iconCornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    private let iconView: FavoriteSiteIconView = {
        let view = FavoriteSiteIconView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = FavoriteSiteCollectionViewCell.titleFont
        label.textAlignment = .center
        label.textColor = .appLabel
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private var shadowWidthConstraint: NSLayoutConstraint?
    private var shadowHeightConstraint: NSLayoutConstraint?
    private var shadowTopConstraint: NSLayoutConstraint?
    private(set) var reorderState: ReorderState = .resting
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        iconView.reset()
        setReorderState(.resting, animated: false)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateIconSize()
        updateShadowColor()
    }
    
    func configure(favorite: BookmarkSnapshot, titleColor: UIColor) {
        titleLabel.text = favorite.title
        titleLabel.textColor = titleColor
        iconView.configure(bookmark: favorite)
    }
    
    func setReorderState(_ state: ReorderState, animated: Bool) {
        reorderState = state
        applyReorderState(animated: animated)
    }
    
    // MARK: - Configuration
    
    private func configureCell() {
        configureAppearance()
        configureHierarchy()
        configureConstraints()
    }
    
    private func configureAppearance() {
        backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
    }
    
    private func configureHierarchy() {
        contentView.addSubview(shadowView)
        shadowView.addSubview(iconBackgroundView)
        iconBackgroundView.addSubview(iconView)
        contentView.addSubview(titleLabel)
    }
    
    private func configureConstraints() {
        let shadowWidthConstraint = shadowView.widthAnchor.constraint(equalToConstant: UX.maximumIconSize)
        let shadowHeightConstraint = shadowView.heightAnchor.constraint(equalToConstant: UX.maximumIconSize)
        let shadowTopConstraint = shadowView.topAnchor.constraint(equalTo: contentView.topAnchor)
        self.shadowWidthConstraint = shadowWidthConstraint
        self.shadowHeightConstraint = shadowHeightConstraint
        self.shadowTopConstraint = shadowTopConstraint
        
        NSLayoutConstraint.activate([
            shadowTopConstraint,
            shadowView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shadowWidthConstraint,
            shadowHeightConstraint,
            
            iconBackgroundView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            iconBackgroundView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            iconBackgroundView.topAnchor.constraint(equalTo: shadowView.topAnchor),
            iconBackgroundView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),
            
            iconView.leadingAnchor.constraint(equalTo: iconBackgroundView.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: iconBackgroundView.trailingAnchor),
            iconView.topAnchor.constraint(equalTo: iconBackgroundView.topAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconBackgroundView.bottomAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: shadowView.bottomAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: UX.titleHeight),
        ])
    }
    
    // MARK: - Layout
    
    private func updateIconSize() {
        let iconSize = currentIconSize()
        if abs((shadowWidthConstraint?.constant ?? 0) - iconSize) > 0.5 {
            shadowWidthConstraint?.constant = iconSize
        }
        if abs((shadowHeightConstraint?.constant ?? 0) - iconSize) > 0.5 {
            shadowHeightConstraint?.constant = iconSize
        }
        iconBackgroundView.layer.cornerRadius = cornerRadius(for: iconSize)
    }
    
    private func updateShadowColor() {
        let iconSize = currentIconSize()
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowPath = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: CGSize(width: iconSize, height: iconSize)),
            cornerRadius: cornerRadius(for: iconSize)
        ).cgPath
    }
    
    private func applyReorderState(animated: Bool) {
        let outset = reorderState == .lifted ? UX.reorderLiftedOutset : 0
        shadowTopConstraint?.constant = -outset
        updateIconSize()
        updateShadowColor()
        
        let animations = {
            self.contentView.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(
                withDuration: UX.reorderLiftAnimationDuration,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState],
                animations: animations
            )
        } else {
            animations()
        }
    }
    
    private func currentIconSize() -> CGFloat {
        let iconSize = min(bounds.width, UX.maximumIconSize)
        return reorderState == .lifted ? iconSize + (UX.reorderLiftedOutset * 2) : iconSize
    }
    
    private func cornerRadius(for iconSize: CGFloat) -> CGFloat {
        return iconSize / UX.maximumIconSize * UX.iconCornerRadius
    }
}
