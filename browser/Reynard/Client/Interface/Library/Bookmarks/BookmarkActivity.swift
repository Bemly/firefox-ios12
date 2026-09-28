//
//  BookmarkActivity.swift
//  Reynard
//
//  Created by Minh Ton on 22/9/26.
//

import UIKit

final class BookmarkActivity: UIActivity {
    static let identifier = UIActivity.ActivityType("com.minh-ton.Reynard.BookmarkActivity")
    private let url: URL
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    override class var activityCategory: UIActivity.Category { .action }
    override var activityType: UIActivity.ActivityType? { Self.identifier }
    override var activityTitle: String? {
        BookmarkStore.shared.bookmark(savedFor: url) == nil
        ? NSLocalizedString("Add Bookmark", comment: "")
        : NSLocalizedString("Edit Bookmark", comment: "")
    }
    override var activityImage: UIImage? { UIImage(named: "reynard.book") }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return url.host != nil
    }
    
    override func perform() {
        activityDidFinish(true)
    }
}

final class AddToFavoritesActivity: UIActivity {
    static let identifier = UIActivity.ActivityType("com.minh-ton.Reynard.AddToFavoritesActivity")
    private let url: URL
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    override class var activityCategory: UIActivity.Category { .action }
    override var activityType: UIActivity.ActivityType? { Self.identifier }
    override var activityTitle: String? { NSLocalizedString("Add to Favorites", comment: "") }
    override var activityImage: UIImage? { UIImage(named: "reynard.star") }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return url.host != nil && !BookmarkStore.shared.isSavedInFavorites(url)
    }
    
    override func perform() {
        activityDidFinish(true)
    }
}
