//
//  UniversalLinkManager.swift
//  Reynard
//
//  Created by Minh Ton on 12/8/26.
//

import Foundation
import GeckoView
import UIKit

final class UniversalLinkManager {
    private struct HandoffKey: Hashable {
        let session: ObjectIdentifier
        let uri: String
    }

    // In-flight handoffs per (session, uri); waiting callers join the first one.
    private var handoffCompletions: [HandoffKey: [(AllowOrDeny) -> Void]] = [:]
    private var failedHandoffs = Set<HandoffKey>()

    func decideHandoff(
        for request: LoadRequest,
        in session: GeckoSession,
        completion: @escaping (AllowOrDeny) -> Void
    ) {
        guard
            Prefs.BrowsingSettings.openLinksInExternalApps,
            !session.isPrivateMode,
            request.isUserInitiatedNavigation,
            let url = URL(string: request.uri),
            URLUtils.isWebURL(url)
        else {
            completion(.allow)
            return
        }

        if let triggerUri = request.triggerUri,
           let triggerURL = URL(string: triggerUri),
           let triggerHost = triggerURL.host,
           let destinationHost = url.host,
           triggerHost.caseInsensitiveCompare(destinationHost) == .orderedSame {
            completion(.allow)
            return
        }

        let key = HandoffKey(session: ObjectIdentifier(session), uri: request.uri)
        if failedHandoffs.contains(key) {
            completion(.allow)
            return
        }
        if handoffCompletions[key] != nil {
            handoffCompletions[key]?.append(completion)
            return
        }
        handoffCompletions[key] = [completion]

        open(url) { [weak self] didOpen in
            guard let self else { return }
            let completions = self.handoffCompletions.removeValue(forKey: key) ?? []
            if didOpen {
                self.failedHandoffs.remove(key)
            } else {
                self.failedHandoffs.insert(key)
            }
            for completion in completions {
                completion(didOpen ? .deny : .allow)
            }
        }
    }

    func didCommitNavigation(in session: GeckoSession) {
        let sessionID = ObjectIdentifier(session)
        failedHandoffs = Set(failedHandoffs.filter { $0.session != sessionID })
    }

    func didCreateNewSession(from session: GeckoSession, for uri: String) {
        failedHandoffs.remove(
            HandoffKey(session: ObjectIdentifier(session), uri: uri)
        )
    }

    // Must run on the main thread (decideHandoff is invoked from engine
    // delegates, which dispatch there). The 5-second timeout mirrors the
    // upstream gate so a stuck open() call can't wedge navigation.
    private func open(_ url: URL, completion: @escaping (Bool) -> Void) {
        var finished = false
        let finish: (Bool) -> Void = { result in
            guard !finished else { return }
            finished = true
            completion(result)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            finish(false)
        }
        UIApplication.shared.open(
            url,
            options: [.universalLinksOnly: true],
            completionHandler: { success in
                finish(success)
            }
        )
    }
}
