//
//  FavoriteFolderCollectionViewCell.swift
//  Reynard
//
//  Created by Minh Ton on 22/6/26.
//

import UIKit

final class FavoriteFolderCollectionViewCell: UICollectionViewCell {
    private enum UX {
        static let maximumIconSize: CGFloat = 74
        // PERF flat-chrome: rounded corners removed for compositing test.
        static let iconCornerRadius: CGFloat = 0
        static let titleHeight: CGFloat = 34
        static let titleFontSize: CGFloat = 12
        static let previewInset: CGFloat = 7
        static let previewSpacing: CGFloat = 5
        static let previewIconCornerRadius: CGFloat = 0
        static let emptyIconSize: CGFloat = 64
        static let reorderLiftedOutset: CGFloat = 4
        static let reorderLiftAnimationDuration: TimeInterval = 0.18
    }
    
    enum ReorderState {
        case resting
        case lifted
    }
    
    static let reuseIdentifier = "FavoriteFolderCollectionViewCell"
    
    var contextMenuAnchorView: UIView {
        return folderBackgroundView
    }
    
    private static let titleFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .semibold)
    )
    
    private let folderBackgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .appSystemGray5
        view.layer.applyContinuousCornerCurve()
        view.layer.cornerRadius = UX.iconCornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    private let emptyIconView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.image = UIImage(named: "reynard.folder")?.withRenderingMode(.alwaysTemplate)
        view.tintColor = .white
        return view
    }()
    
    private let previewGridView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = FavoriteFolderCollectionViewCell.titleFont
        label.textAlignment = .center
        label.textColor = .appLabel
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private var previewIconViews: [FavoriteSiteIconView] = []
    private var folderWidthConstraint: NSLayoutConstraint?
    private var folderHeightConstraint: NSLayoutConstraint?
    private var folderTopConstraint: NSLayoutConstraint?
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
        previewIconViews.forEach { $0.reset() }
        configurePreview(bookmarks: [])
        setReorderState(.resting, animated: false)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateFolderSize()
    }
    
    func configure(
        folder: BookmarkFolderSnapshot,
        previewBookmarks: [BookmarkSnapshot],
        titleColor: UIColor
    ) {
        titleLabel.text = folder.title
        titleLabel.textColor = titleColor
        configurePreview(bookmarks: Array(previewBookmarks.prefix(4)))
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
        configurePreviewIconViews()
        configurePreview(bookmarks: [])
    }
    
    private func configureAppearance() {
        backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
    }
    
    private func configureHierarchy() {
        contentView.addSubview(folderBackgroundView)
        folderBackgroundView.addSubview(emptyIconView)
        folderBackgroundView.addSubview(previewGridView)
        contentView.addSubview(titleLabel)
    }
    
    private func configureConstraints() {
        let folderWidthConstraint = folderBackgroundView.widthAnchor.constraint(equalToConstant: UX.maximumIconSize)
        let folderHeightConstraint = folderBackgroundView.heightAnchor.constraint(equalToConstant: UX.maximumIconSize)
        let folderTopConstraint = folderBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor)
        self.folderWidthConstraint = folderWidthConstraint
        self.folderHeightConstraint = folderHeightConstraint
        self.folderTopConstraint = folderTopConstraint
        
        NSLayoutConstraint.activate([
            folderTopConstraint,
            folderBackgroundView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            folderWidthConstraint,
            folderHeightConstraint,
            
            emptyIconView.centerXAnchor.constraint(equalTo: folderBackgroundView.centerXAnchor),
            emptyIconView.centerYAnchor.constraint(equalTo: folderBackgroundView.centerYAnchor),
            emptyIconView.widthAnchor.constraint(equalToConstant: UX.emptyIconSize),
            emptyIconView.heightAnchor.constraint(equalToConstant: UX.emptyIconSize),
            
            previewGridView.leadingAnchor.constraint(equalTo: folderBackgroundView.leadingAnchor, constant: UX.previewInset),
            previewGridView.trailingAnchor.constraint(equalTo: folderBackgroundView.trailingAnchor, constant: -UX.previewInset),
            previewGridView.topAnchor.constraint(equalTo: folderBackgroundView.topAnchor, constant: UX.previewInset),
            previewGridView.bottomAnchor.constraint(equalTo: folderBackgroundView.bottomAnchor, constant: -UX.previewInset),
            
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: folderBackgroundView.bottomAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: UX.titleHeight),
        ])
    }
    
    private func configurePreviewIconViews() {
        for _ in 0..<4 {
            let iconView = FavoriteSiteIconView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.backgroundColor = .white
            iconView.clipsToBounds = true
            iconView.layer.applyContinuousCornerCurve()
            iconView.layer.cornerRadius = UX.previewIconCornerRadius
            previewGridView.addSubview(iconView)
            previewIconViews.append(iconView)
        }
        
        NSLayoutConstraint.activate([
            previewIconViews[0].leadingAnchor.constraint(equalTo: previewGridView.leadingAnchor),
            previewIconViews[0].topAnchor.constraint(equalTo: previewGridView.topAnchor),
            previewIconViews[0].trailingAnchor.constraint(equalTo: previewGridView.centerXAnchor, constant: -(UX.previewSpacing / 2)),
            previewIconViews[0].bottomAnchor.constraint(equalTo: previewGridView.centerYAnchor, constant: -(UX.previewSpacing / 2)),
            
            previewIconViews[1].leadingAnchor.constraint(equalTo: previewGridView.centerXAnchor, constant: UX.previewSpacing / 2),
            previewIconViews[1].topAnchor.constraint(equalTo: previewGridView.topAnchor),
            previewIconViews[1].trailingAnchor.constraint(equalTo: previewGridView.trailingAnchor),
            previewIconViews[1].bottomAnchor.constraint(equalTo: previewGridView.centerYAnchor, constant: -(UX.previewSpacing / 2)),
            
            previewIconViews[2].leadingAnchor.constraint(equalTo: previewGridView.leadingAnchor),
            previewIconViews[2].topAnchor.constraint(equalTo: previewGridView.centerYAnchor, constant: UX.previewSpacing / 2),
            previewIconViews[2].trailingAnchor.constraint(equalTo: previewGridView.centerXAnchor, constant: -(UX.previewSpacing / 2)),
            previewIconViews[2].bottomAnchor.constraint(equalTo: previewGridView.bottomAnchor),
            
            previewIconViews[3].leadingAnchor.constraint(equalTo: previewGridView.centerXAnchor, constant: UX.previewSpacing / 2),
            previewIconViews[3].topAnchor.constraint(equalTo: previewGridView.centerYAnchor, constant: UX.previewSpacing / 2),
            previewIconViews[3].trailingAnchor.constraint(equalTo: previewGridView.trailingAnchor),
            previewIconViews[3].bottomAnchor.constraint(equalTo: previewGridView.bottomAnchor),
        ])
    }
    
    private func configurePreview(bookmarks: [BookmarkSnapshot]) {
        emptyIconView.isHidden = !bookmarks.isEmpty
        previewGridView.isHidden = bookmarks.isEmpty
        
        for index in previewIconViews.indices {
            let iconView = previewIconViews[index]
            guard bookmarks.indices.contains(index) else {
                iconView.reset()
                iconView.isHidden = true
                continue
            }
            
            iconView.isHidden = false
            iconView.configure(bookmark: bookmarks[index])
        }
    }
    
    // MARK: - Layout
    
    private func updateFolderSize() {
        let iconSize = currentIconSize()
        if abs((folderWidthConstraint?.constant ?? 0) - iconSize) > 0.5 {
            folderWidthConstraint?.constant = iconSize
        }
        if abs((folderHeightConstraint?.constant ?? 0) - iconSize) > 0.5 {
            folderHeightConstraint?.constant = iconSize
        }
        folderBackgroundView.layer.cornerRadius = iconSize / UX.maximumIconSize * UX.iconCornerRadius
    }
    
    private func applyReorderState(animated: Bool) {
        let outset = reorderState == .lifted ? UX.reorderLiftedOutset : 0
        folderTopConstraint?.constant = -outset
        updateFolderSize()
        
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
}
