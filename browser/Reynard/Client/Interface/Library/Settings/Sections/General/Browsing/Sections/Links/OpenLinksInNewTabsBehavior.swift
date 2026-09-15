//
//  OpenLinksInNewTabsBehavior.swift
//  Reynard
//
//  Created by Minh Ton on 9/9/26.
//

import Foundation

enum OpenLinksInNewTabsBehavior: String, CaseIterable {
    case switchTabImmediately
    case openInBackground
    
    var title: String {
        switch self {
        case .switchTabImmediately:
            return NSLocalizedString("Switch Tab Immediately", comment: "")
        case .openInBackground:
            return NSLocalizedString("Open in Background", comment: "Open links in new tab behavior")
        }
    }
}
