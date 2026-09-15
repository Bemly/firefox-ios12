//
//  ContentBlockingController.swift
//  Reynard
//
//  Created by Minh Ton on 23/7/26.
//

import Foundation

public enum ContentBlockingController {
    public static func blockedTrackers(
        for session: GeckoSession,
        completion: @escaping (Result<[BlockedTracker], Error>) -> Void
    ) {
        session.dispatcher.query(type: "ContentBlocking:RequestLog") { result in
            switch result {
            case .success(let response):
                completion(.success(Self.parseBlockedTrackers(from: response)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func parseBlockedTrackers(from response: Any?) -> [BlockedTracker] {
        guard let payload = response as? [String: Any],
              let entries = payload["log"] as? [[String: Any]] else {
            return []
        }

        return entries.compactMap { entry in
            guard let origin = entry["origin"] as? String,
                  let blockingData = entry["blockData"] as? [[String: Any]] else {
                return nil
            }
            let events = blockingData.compactMap { data in
                return PayloadValue.int64(data["category"]).map {
                    Int64(UInt32(truncatingIfNeeded: $0))
                }
            }
            guard let category = primaryCategory(for: events) else {
                return nil
            }
            return BlockedTracker(url: origin, categories: [category])
        }
    }

    
    private static func primaryCategory(for events: [Int64]) -> BlockedTrackerCategory? {
        if events.contains(where: { [0x00000040, 0x00000004, 0x08000000].contains($0) }) {
            return .fingerprinters
        }
        if events.contains(0x00000800) {
            return .cryptominers
        }
        if events.contains(0x00010000) || events.contains(0x01000000) {
            return .socialMediaTrackers
        }
        if events.contains(where: { [0x00001000, 0x00000010, 0x00400000, 0x00000008].contains($0) }) {
            return .trackingContent
        }
        let blockedCookieEvents: Set<Int64> = [
            0x10000000,
            0x20000000,
            0x40000000,
            0x00000002,
            0x80000000,
            0x00000080,
            0x01000000,
        ]
        return events.contains(where: blockedCookieEvents.contains)
        ? .crossSiteTrackingCookies
        : nil
    }
}
