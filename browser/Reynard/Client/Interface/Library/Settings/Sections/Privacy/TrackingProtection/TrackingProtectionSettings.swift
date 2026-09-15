//
//  TrackingProtectionSettings.swift
//  Reynard
//
//  Created by Minh Ton on 22/7/26.
//

enum TrackingProtectionLevel: String {
    case standard
    case strict
    case custom
    case off
}

enum CustomCookiePolicy: Int {
    case isolateCrossSite = 5
    case crossSiteAndSocialTrackers = 4
    case unvisitedWebsites = 3
    case thirdParty = 1
    case all = 2
    case none = 0
}

enum CustomBlockingScope: String {
    case all
    case privateOnly
    case none
}
