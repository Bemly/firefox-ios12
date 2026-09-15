//
//  ContentBlockingDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 23/7/26.
//

import Foundation

public enum BlockedTrackerCategory: CaseIterable {
    case crossSiteTrackingCookies
    case cryptominers
    case fingerprinters
    case socialMediaTrackers
    case trackingContent
}

public struct BlockedTracker {
    public let url: String
    public let categories: Set<BlockedTrackerCategory>
}

public protocol ContentBlockingDelegate: AnyObject {
    func contentBlockingDelegate(_ session: GeckoSession, blocked tracker: BlockedTracker)
}

public extension ContentBlockingDelegate {
    func contentBlockingDelegate(_ session: GeckoSession, blocked tracker: BlockedTracker) {}
}

private enum ContentBlockingEvents: String {
    case blocked = "GeckoView:ContentBlockingEvent"
}

func newContentBlockingHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    return GeckoSessionHandler(
        moduleName: "GeckoViewContentBlocking",
        events: [ContentBlockingEvents.blocked.rawValue],
        session: session
    ) { @MainActor session, delegate, _, message in
        guard let tracker = BlockedTracker(message: message) else {
            return nil
        }
        (delegate as? ContentBlockingDelegate)?.contentBlockingDelegate(session, blocked: tracker)
        return nil
    }
}

private extension BlockedTracker {
    static let blockedCookieFlags: Int64 =
    0x10000000 | 0x20000000 | 0x01000000 | 0x40000000 | 0x00000002 | 0x80000000 | 0x80
    
    init?(message: [String: Any?]?) {
        guard let message,
              let url = message["uri"] as? String else {
            return nil
        }
        
        let blockedList = message["blockedList"] as? String
        let error = PayloadValue.int64(message["error"] ?? nil) ?? 0
        let flags = PayloadValue.int64(message["category"] ?? nil) ?? 0
        guard blockedList != nil || error != 0 || flags & Self.blockedCookieFlags != 0 else {
            return nil
        }
        
        var categories = Set<BlockedTrackerCategory>()
        if flags & Self.blockedCookieFlags != 0 {
            categories.insert(.crossSiteTrackingCookies)
        }
        if blockedList?.contains("base-cryptomining-track-digest256") == true {
            categories.insert(.cryptominers)
        }
        if blockedList?.contains("base-fingerprinting-track-digest256") == true {
            categories.insert(.fingerprinters)
        }
        if blockedList?.contains("social-track-digest256") == true
            || blockedList?.contains("social-tracking-protection-") == true {
            categories.insert(.socialMediaTrackers)
        }
        if blockedList?.contains("ads-track-digest256") == true
            || blockedList?.contains("analytics-track-digest256") == true
            || blockedList?.contains("content-track-digest256") == true
            || blockedList?.contains("base-email-track-digest256") == true {
            categories.insert(.trackingContent)
        }
        
        guard !categories.isEmpty else {
            return nil
        }
        self.url = url
        self.categories = categories
    }
}
