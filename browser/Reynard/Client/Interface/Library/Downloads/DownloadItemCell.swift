//
//  DownloadItemCell.swift
//  Reynard
//
//  Created by Minh Ton on 2/4/26.
//

import UIKit

final class DownloadItemCell: UITableViewCell {
    private enum UX {
        static let labelsStackSpacing: CGFloat = 4
        static let iconSize: CGFloat = 44
        static let iconVerticalInset: CGFloat = 8
        static let labelsLeadingSpacing: CGFloat = 13
        static let labelsVerticalInset: CGFloat = 13
        static let separatorLeftInset: CGFloat = 73
        static let thumbnailRequestSize = CGSize(width: 56, height: 56)
    }
    
    static let reuseIdentifier = "DownloadItemCell"
    
    private static let iconProvider = DownloadFileIconProvider.shared
    
    private static let sizeNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    private let fileIconView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = .appLabel
        return view
    }()
    
    private let fileNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .appLabel
        label.numberOfLines = 1
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .appSecondaryLabel
        label.numberOfLines = 2
        return label
    }()
    
    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.trackTintColor = .appTertiarySystemFill
        view.progressTintColor = .appLabel
        view.isHidden = true
        return view
    }()
    
    private var representedFileURL: URL?
    private var representedDownloadID: UUID?
    
    // MARK: - Lifecycle
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        
        let labelsStack = UIStackView(arrangedSubviews: [fileNameLabel, statusLabel, progressView])
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        labelsStack.axis = .vertical
        labelsStack.alignment = .fill
        labelsStack.spacing = UX.labelsStackSpacing
        
        contentView.addSubview(fileIconView)
        contentView.addSubview(labelsStack)
        
        NSLayoutConstraint.activate([
            fileIconView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            fileIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fileIconView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: UX.iconVerticalInset),
            fileIconView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -UX.iconVerticalInset),
            fileIconView.widthAnchor.constraint(equalToConstant: UX.iconSize),
            fileIconView.heightAnchor.constraint(equalToConstant: UX.iconSize),
            
            labelsStack.leadingAnchor.constraint(equalTo: fileIconView.trailingAnchor, constant: UX.labelsLeadingSpacing),
            labelsStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            labelsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelsStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: UX.labelsVerticalInset),
            labelsStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -UX.labelsVerticalInset),
        ])
        
        separatorInset.left = UX.separatorLeftInset
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        LibrarySharedUtils.alignSeparatorWithReadableContent(in: self)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        representedFileURL = nil
        representedDownloadID = nil
        contentView.alpha = 1
        fileNameLabel.textColor = .appLabel
        statusLabel.textColor = .appSecondaryLabel
        fileIconView.image = nil
        fileIconView.transform = .identity
        fileIconView.tintColor = .appLabel
    }
    
    // MARK: - Configuration
    
    func configure(with item: DownloadItemSnapshot) {
        fileNameLabel.text = item.fileName
        let isDeleted = item.state == .completed && !item.fileExists
        let isUnavailable = isDeleted || item.state == .cancelled || item.state == .failed
        contentView.alpha = isUnavailable ? 0.45 : 1
        fileNameLabel.textColor = isUnavailable ? .appSecondaryLabel : .appLabel
        statusLabel.textColor = .appSecondaryLabel
        
        switch item.state {
        case .downloading:
            configureDownloading(item)
            
        case .paused:
            representedFileURL = nil
            representedDownloadID = item.id
            statusLabel.text = NSLocalizedString("Paused", comment: "Download state")
            progressView.isHidden = true
            progressView.progress = 0
            let placeholderIcon = Self.iconProvider.genericPlaceholderIcon()
            fileIconView.image = placeholderIcon
            fileIconView.transform = .identity
            fileIconView.tintColor = placeholderIcon == nil ? .appLabel : nil
            
        case .cancelled, .failed:
            representedFileURL = nil
            representedDownloadID = item.id
            statusLabel.text = item.state == .cancelled
            ? NSLocalizedString("Cancelled", comment: "Download state")
            : NSLocalizedString("Failed", comment: "Download state")
            progressView.isHidden = true
            progressView.progress = 0
            fileIconView.image = Self.iconProvider.genericPlaceholderIcon()
            fileIconView.transform = .identity
            fileIconView.tintColor = nil
            
        case .completed:
            representedDownloadID = item.id
            statusLabel.text = item.fileExists ? (item.totalBytes.map { Self.formattedByteCount($0) } ?? NSLocalizedString("Unknown size", comment: "")) : NSLocalizedString("Deleted", comment: "")
            progressView.isHidden = true
            progressView.progress = 0
            fileIconView.transform = .identity
            fileIconView.tintColor = nil
            
            guard item.fileExists else {
                representedFileURL = nil
                fileIconView.image = Self.iconProvider.genericPlaceholderIcon()
                return
            }
            
            representedFileURL = item.fileURL
            fileIconView.image = item.fileURL.flatMap { Self.iconProvider.cachedIcon(for: $0) } ?? Self.iconProvider.genericPlaceholderIcon()
            
            guard let fileURL = item.fileURL else {
                return
            }
            
            Self.iconProvider.icon(for: fileURL, size: UX.thumbnailRequestSize) { [weak self] image in
                guard let self, self.representedFileURL == fileURL else {
                    return
                }
                
                if let image {
                    self.fileIconView.image = image
                } else {
                    self.fileIconView.image = Self.iconProvider.placeholderIcon(for: fileURL) ?? Self.iconProvider.genericPlaceholderIcon()
                }
            }
        }
    }
    
    private func configureDownloading(_ item: DownloadItemSnapshot) {
        representedFileURL = nil
        representedDownloadID = item.id
        let downloadedText = Self.formattedByteCount(item.downloadedBytes)
        let sizeText = item.totalBytes.map { Self.formattedByteCount($0) }
        
        let speedText: String?
        if item.bytesPerSecond > 0 {
            speedText = String(format: NSLocalizedString("%@/sec", comment: "Download speed"), Self.formattedByteCount(item.bytesPerSecond))
        } else {
            speedText = nil
        }
        
        var detailsText = downloadedText
        if let sizeText {
            detailsText += String(format: NSLocalizedString(" of %@", comment: "Total file size"), sizeText)
        }
        if let speedText {
            detailsText += " (\(speedText))"
        }
        statusLabel.text = detailsText
        
        progressView.isHidden = false
        if let totalBytes = item.totalBytes, totalBytes > 0 {
            progressView.progress = min(max(Float(item.downloadedBytes) / Float(totalBytes), 0), 1)
        } else {
            progressView.progress = 0
        }
        let placeholderIcon = Self.iconProvider.genericPlaceholderIcon()
        fileIconView.image = placeholderIcon
        fileIconView.transform = .identity
        fileIconView.tintColor = placeholderIcon == nil ? .appLabel : nil
    }
    
    // MARK: - Formatting
    
    private static func formattedByteCount(_ byteCount: Int64) -> String {
        let units = [
            NSLocalizedString("bytes", comment: ""),
            "KB",
            "MB",
            "GB",
            "TB",
        ]
        var value = Double(abs(byteCount))
        var unitIndex = 0
        
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            let bytesText = Int64(value)
            return "\(byteCount < 0 ? -bytesText : bytesText) \(units[unitIndex])"
        }
        
        let formattedValue = sizeNumberFormatter.string(from: NSNumber(value: byteCount < 0 ? -value : value)) ?? String(format: "%.1f", byteCount < 0 ? -value : value)
        return "\(formattedValue) \(units[unitIndex])"
    }
}
