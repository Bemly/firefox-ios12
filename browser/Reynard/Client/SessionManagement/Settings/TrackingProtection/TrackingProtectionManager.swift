//
//  TrackingProtectionManager.swift
//  Reynard
//
//  Created by Minh Ton on 23/7/26.
//

import GeckoView

protocol TrackingProtectionManagerObserver: AnyObject {
    func trackingProtectionManager(
        _ manager: TrackingProtectionManager,
        didUpdate session: GeckoSession
    )
}

final class TrackingProtectionManager {
    private final class WeakObserver {
        weak var value: TrackingProtectionManagerObserver?
        
        init(_ value: TrackingProtectionManagerObserver) {
            self.value = value
        }
    }
    
    private var blockedTrackersBySession: [ObjectIdentifier: [BlockedTracker]] = [:]
    private var observers: [WeakObserver] = []
    
    func addObserver(_ observer: TrackingProtectionManagerObserver) {
        observers.removeAll { $0.value == nil || $0.value === observer }
        observers.append(WeakObserver(observer))
    }
    
    func removeObserver(_ observer: TrackingProtectionManagerObserver) {
        observers.removeAll { $0.value == nil || $0.value === observer }
    }
    
    func blockedTrackers(for session: GeckoSession) -> [BlockedTracker] {
        return blockedTrackersBySession[ObjectIdentifier(session)] ?? []
    }
    
    func clearBlockedTrackers(for session: GeckoSession) {
        blockedTrackersBySession[ObjectIdentifier(session)] = []
        notifyObservers(for: session)
    }
    
    func refreshBlockedTrackers(
        for session: GeckoSession,
        completion: (() -> Void)? = nil
    ) {
        ContentBlockingController.blockedTrackers(for: session) { [weak self] result in
            guard let self else { return }
            self.blockedTrackersBySession[ObjectIdentifier(session)] = (try? result.get()) ?? []
            self.notifyObservers(for: session)
            completion?()
        }
    }
    
    func removeSession(_ session: GeckoSession) {
        blockedTrackersBySession.removeValue(forKey: ObjectIdentifier(session))
    }
    
    private func notifyObservers(for session: GeckoSession) {
        observers.removeAll { observer in
            guard let observer = observer.value else {
                return true
            }
            observer.trackingProtectionManager(self, didUpdate: session)
            return false
        }
    }
}

extension TrackingProtectionManager: ContentBlockingDelegate {
    func contentBlockingDelegate(_ session: GeckoSession, blocked tracker: BlockedTracker) {
        blockedTrackersBySession[ObjectIdentifier(session), default: []].append(tracker)
        notifyObservers(for: session)
    }
}
