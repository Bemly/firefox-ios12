//
//  BookmarkItemCell.swift
//  Reynard
//
//  Created by Minh Ton on 23/5/26.
//

import UIKit

final class BookmarkItemCell: UITableViewCell {
    private enum UX {
        static let iconSize: CGFloat = 26
        static let titleLeadingSpacing: CGFloat = 13
        static let titleToCountSpacing: CGFloat = 8
        static let separatorLeftInset: CGFloat = 56
        static let faviconCornerRadius: CGFloat = 6
    }
    
    static let reuseIdentifier = "BookmarkItemCell"
    
    private static let faviconStore = FaviconStore.shared
    
    private let itemIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = UX.faviconCornerRadius
        return imageView
    }()
    
    private let itemTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .appLabel
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        return label
    }()
    private let countLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .appSecondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .right
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    private var representedURL: URL?
    private var faviconLoadToken: UUID?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        clipsToBounds = true
        contentView.clipsToBounds = true
        
        contentView.addSubview(itemIconView)
        contentView.addSubview(itemTitleLabel)
        contentView.addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            itemIconView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            itemIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            itemIconView.widthAnchor.constraint(equalToConstant: UX.iconSize),
            itemIconView.heightAnchor.constraint(equalToConstant: UX.iconSize),
            
            itemTitleLabel.leadingAnchor.constraint(equalTo: itemIconView.trailingAnchor, constant: UX.titleLeadingSpacing),
            itemTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -UX.titleToCountSpacing),
            itemTitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            countLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        
        separatorInset.left = UX.separatorLeftInset
        applyIcon(UIImage(named: "reynard.globe"), tintColor: .appSecondaryLabel)
    }
    
    // MARK: - Reuse And Layout
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        LibrarySharedUtils.alignSeparatorWithReadableContent(in: self)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        representedURL = nil
        faviconLoadToken = nil
        itemTitleLabel.text = nil
        countLabel.text = nil
        countLabel.isHidden = true
        applyIcon(UIImage(named: "reynard.globe"), tintColor: .appSecondaryLabel)
    }
    
    // MARK: - Configuration
    
    func configure(folder: BookmarkFolderSnapshot) {
        representedURL = nil
        faviconLoadToken = nil
        itemTitleLabel.text = folder.isProtected && folder.title == "Favorites" ? NSLocalizedString("Favorites", comment: "") : folder.title
        countLabel.text = "\(folder.childCount)"
        countLabel.isHidden = false
        
        if folder.isProtected && folder.title == "Favorites" {
            applyIcon(UIImage(named: "reynard.star"), tintColor: .appSecondaryLabel)
        } else {
            applyIcon(UIImage(named: "reynard.folder"), tintColor: .appSecondaryLabel)
        }
    }
    
    func configure(bookmark: BookmarkSnapshot) {
        representedURL = bookmark.url
        faviconLoadToken = nil
        itemTitleLabel.text = bookmark.title
        countLabel.text = nil
        countLabel.isHidden = true
        
        if let cachedImage = Self.faviconStore.cachedFavicon(for: bookmark.url) {
            applyIcon(cachedImage, tintColor: nil)
            return
        }
        
        applyIcon(UIImage(named: "reynard.globe"), tintColor: .appSecondaryLabel)
        let expectedURL = bookmark.url
        let token = UUID()
        faviconLoadToken = token
        Self.faviconStore.favicon(for: expectedURL) { [weak self] image in
            guard let self else {
                return
            }

            guard self.faviconLoadToken == token else {
                return
            }

            guard self.representedURL == expectedURL else {
                return
            }

            self.applyIcon(image ?? UIImage(named: "reynard.globe"), tintColor: image == nil ? .appSecondaryLabel : nil)
        }
    }
    
    private func applyIcon(_ image: UIImage?, tintColor: UIColor?) {
        itemIconView.image = image
        itemIconView.tintColor = tintColor
    }
}
