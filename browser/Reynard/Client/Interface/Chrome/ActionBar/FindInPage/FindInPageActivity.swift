//
//  FindInPageActivity.swift
//  Reynard
//
//  Created by Minh Ton on 22/9/26.
//

import UIKit

final class FindInPageActivity: UIActivity {
    static let identifier = UIActivity.ActivityType("com.minh-ton.Reynard.FindInPageActivity")
    private let url: URL
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    override class var activityCategory: UIActivity.Category { .action }
    override var activityType: UIActivity.ActivityType? { Self.identifier }
    override var activityTitle: String? { NSLocalizedString("Find in Page", comment: "") }
    override var activityImage: UIImage? { UIImage(named: "reynard.text.page.badge.magnifyingglass") }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return url.host != nil
    }
    
    override func perform() {
        activityDidFinish(true)
    }
}
