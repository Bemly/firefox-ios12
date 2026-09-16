//
//  RecentlyClosedTabCollectionViewCell.swift
//  Reynard
//
//  Created by Minh Ton on 25/6/26.
//

import UIKit

final class RecentlyClosedTabCollectionViewCell: UICollectionViewCell {
    private enum UX {
        static let horizontalInset: CGFloat = 16
        static let titleFontSize: CGFloat = 15
        // PERF flat-chrome: rounded corners + shadow removed for compositing test.
        static let pillCornerRadius: CGFloat = 0
        static let shadowOpacity: Float = 0
        static let shadowRadius: CGFloat = 5
        static let shadowOffsetWidth: CGFloat = 0
        static let shadowOffsetHeight: CGFloat = 2
    }
    
    static let reuseIdentifier = "RecentlyClosedTabCollectionViewCell"
    
    private static let titleFont = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .regular)
    )
    
    private let pillView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .appChromeMaterial))
        view.appDisableBackdropBlurForIOS12()
        view.contentView.backgroundColor = view.effect == nil ? .appSecondarySystemBackground : .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.layer.applyContinuousCornerCurve()
        view.layer.cornerRadius = UX.pillCornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = RecentlyClosedTabCollectionViewCell.titleFont
        label.textColor = .appLabel
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
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
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePillShape()
        updatePillShadow()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else {
            return
        }
        
        updateAppearance()
    }
    
    func configure(tab: TabManagementStore.RecentlyClosedTabSnapshot) {
        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        titleLabel.text = title.isEmpty ? NSLocalizedString("Untitled", comment: "") : title
    }
    
    // MARK: - Configuration
    
    private func configureCell() {
        configureAppearance()
        configureHierarchy()
        configureConstraints()
    }
    
    private func configureAppearance() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
        layer.applyContinuousCornerCurve()
        layer.cornerRadius = UX.pillCornerRadius
        layer.shadowOpacity = UX.shadowOpacity
        layer.shadowRadius = UX.shadowRadius
        layer.shadowOffset = CGSize(width: UX.shadowOffsetWidth, height: UX.shadowOffsetHeight)
        updateAppearance()
    }
    
    private func configureHierarchy() {
        contentView.addSubview(pillView)
        pillView.contentView.addSubview(titleLabel)
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            pillView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pillView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pillView.topAnchor.constraint(equalTo: contentView.topAnchor),
            pillView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: pillView.contentView.leadingAnchor, constant: UX.horizontalInset),
            titleLabel.trailingAnchor.constraint(equalTo: pillView.contentView.trailingAnchor, constant: -UX.horizontalInset),
            titleLabel.centerYAnchor.constraint(equalTo: pillView.contentView.centerYAnchor),
        ])
    }
    
    // MARK: - Layout
    
    private func updatePillShape() {
        // PERF flat-chrome: pill shape flattened (was height/2 capsule).
        pillView.layer.cornerRadius = 0
        layer.cornerRadius = 0
    }
    
    private func updatePillShadow() {
        // PERF flat-chrome: shadow removed, no shadowPath needed.
        layer.shadowPath = nil
    }
    
    // MARK: - Appearance
    
    private func updateAppearance() {
        titleLabel.textColor = .appLabel
        layer.shadowColor = UIColor.black.cgColor
    }
}
