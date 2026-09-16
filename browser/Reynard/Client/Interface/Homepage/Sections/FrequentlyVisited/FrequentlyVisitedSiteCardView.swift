//
//  FrequentlyVisitedSiteCardView.swift
//  Reynard
//
//  Created by Minh Ton on 24/6/26.
//

import UIKit

final class FrequentlyVisitedSiteCardView: UIControl {
    private enum UX {
        static let previewCornerRadius: CGFloat = 17
        static let previewImageViewPadding: CGFloat = 3
        static let previewAspectRatio: CGFloat = 9.0 / 16.0
        static let titleFontSize: CGFloat = 12
        static let titleHeight: CGFloat = 30
        static let iconSize: CGFloat = 44
        static let titleTopSpacing: CGFloat = 3
        static let titleBottomSpacing: CGFloat = 3
        static let titleHorizontalInset: CGFloat = 10
        static let shadowOpacity: Float = 0.12
        static let shadowRadius: CGFloat = 5
        static let shadowOffsetWidth: CGFloat = 0
        static let shadowOffsetHeight: CGFloat = 2
    }
    
    private static let titleFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .regular)
    )
    
    private let backgroundView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .appChromeMaterial))
        view.appDisableBackdropBlurForIOS12()
        view.contentView.backgroundColor = view.effect == nil ? .appSecondarySystemBackground : .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.layer.applyContinuousCornerCurve()
        view.layer.cornerRadius = UX.previewCornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    private let previewView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.layer.applyContinuousCornerCurve()
        view.layer.cornerRadius = UX.previewCornerRadius - UX.previewImageViewPadding
        view.clipsToBounds = true
        return view
    }()
    
    private let previewImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()
    
    private let iconView: FrequentlyVisitedIconView = {
        let view = FrequentlyVisitedIconView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: FrequentlyVisitedCardLabel = {
        let label = FrequentlyVisitedCardLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = FrequentlyVisitedSiteCardView.titleFont
        label.textColor = .appLabel
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCard()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPath()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else {
            return
        }
        
        updateAppearance()
    }
    
    
    func configure(site: HistorySiteSnapshot, metadata: SiteMetadataSnapshot?) {
        titleLabel.text = site.title
        iconView.configure(url: site.url)
        
        if let image = metadata?.ogImage {
            previewImageView.image = image
            previewImageView.isHidden = false
            iconView.isHidden = true
        } else {
            previewImageView.image = nil
            previewImageView.isHidden = true
            iconView.isHidden = false
        }
    }
    
    // MARK: - Configuration
    
    private func configureCard() {
        configureAppearance()
        configureHierarchy()
        configureConstraints()
    }
    
    private func configureAppearance() {
        backgroundColor = .clear
        clipsToBounds = false
        layer.shadowOpacity = UX.shadowOpacity
        layer.shadowRadius = UX.shadowRadius
        layer.shadowOffset = CGSize(width: UX.shadowOffsetWidth, height: UX.shadowOffsetHeight)
        layer.applyContinuousCornerCurve()
        layer.cornerRadius = UX.previewCornerRadius
        updateAppearance()
    }
    
    private func configureHierarchy() {
        addSubview(backgroundView)
        addSubview(previewView)
        previewView.addSubview(previewImageView)
        previewView.addSubview(iconView)
        addSubview(titleLabel)
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            previewView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UX.previewImageViewPadding),
            previewView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -UX.previewImageViewPadding),
            previewView.topAnchor.constraint(equalTo: topAnchor, constant: UX.previewImageViewPadding),
            previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: UX.previewAspectRatio),
            
            previewImageView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: previewView.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            
            iconView.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: UX.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: UX.iconSize),
            
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UX.titleHorizontalInset),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -UX.titleHorizontalInset),
            titleLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: UX.titleTopSpacing),
            titleLabel.heightAnchor.constraint(equalToConstant: UX.titleHeight),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -UX.titleBottomSpacing),
        ])
    }
    
    // MARK: - Layout
    
    private func updateShadowPath() {
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: UX.previewCornerRadius
        ).cgPath
    }
    
    // MARK: - Appearance
    
    private func updateAppearance() {
        backgroundColor = .clear
        previewView.backgroundColor = .appSystemGray6
        titleLabel.textColor = .appLabel
        layer.shadowColor = UIColor.black.cgColor
    }
}

private final class FrequentlyVisitedCardLabel: UILabel {
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        var rect = super.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        rect.origin.y = bounds.origin.y
        return rect
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: textRect(forBounds: rect, limitedToNumberOfLines: numberOfLines))
    }
}
