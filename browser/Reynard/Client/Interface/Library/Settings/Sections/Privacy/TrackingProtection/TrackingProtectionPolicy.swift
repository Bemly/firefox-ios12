//
//  TrackingProtectionPolicy.swift
//  Reynard
//
//  Created by Minh Ton on 22/7/26.
//

struct TrackingProtectionPolicy {
    let level: TrackingProtectionLevel
    let baselineAllowListEnabled: Bool
    let convenienceAllowListEnabled: Bool
    let customCookieBehavior: Int
    let customTrackingContentScope: CustomBlockingScope
    let customBlocksCryptominers: Bool
    let customBlocksKnownFingerprinters: Bool
    let customBlocksRedirectTrackers: Bool
    let customSuspectedFingerprinterScope: CustomBlockingScope
    
    init(
        level: TrackingProtectionLevel,
        baselineAllowListEnabled: Bool = true,
        convenienceAllowListEnabled: Bool = false,
        customCookieBehavior: Int = 5,
        customTrackingContentScope: CustomBlockingScope = .all,
        customBlocksCryptominers: Bool = true,
        customBlocksKnownFingerprinters: Bool = true,
        customBlocksRedirectTrackers: Bool = true,
        customSuspectedFingerprinterScope: CustomBlockingScope = .privateOnly
    ) {
        self.level = level
        self.baselineAllowListEnabled = baselineAllowListEnabled
        self.convenienceAllowListEnabled = convenienceAllowListEnabled
        self.customCookieBehavior = customCookieBehavior
        self.customTrackingContentScope = customTrackingContentScope
        self.customBlocksCryptominers = customBlocksCryptominers
        self.customBlocksKnownFingerprinters = customBlocksKnownFingerprinters
        self.customBlocksRedirectTrackers = customBlocksRedirectTrackers
        self.customSuspectedFingerprinterScope = customSuspectedFingerprinterScope
    }
    
    var preferences: [String: Any] {
        switch level {
        case .standard:
            return contentBlockingPreferences(
                category: "standard",
                trackingTable: trackingTable(includingContent: false),
                cryptominingEnabled: true,
                fingerprintingEnabled: true,
                socialTrackingEnabled: true,
                emailTrackingEnabled: false,
                cookieBehavior: 5,
                etpEnabled: true,
                strictListEnabled: false,
                cookiePurgingEnabled: true,
                strictSocialTrackingEnabled: false,
                trackingContentScope: .privateOnly,
                suspectedFingerprinterScope: .privateOnly,
                bounceTrackingProtectionMode: 2,
                baselineAllowListEnabled: true,
                convenienceAllowListEnabled: true
            )
        case .strict:
            return contentBlockingPreferences(
                category: "strict",
                trackingTable: trackingTable(includingContent: true),
                cryptominingEnabled: true,
                fingerprintingEnabled: true,
                socialTrackingEnabled: true,
                emailTrackingEnabled: true,
                cookieBehavior: 5,
                etpEnabled: true,
                strictListEnabled: true,
                cookiePurgingEnabled: true,
                strictSocialTrackingEnabled: true,
                trackingContentScope: .all,
                suspectedFingerprinterScope: .all,
                bounceTrackingProtectionMode: 1,
                baselineAllowListEnabled: baselineAllowListEnabled,
                convenienceAllowListEnabled: convenienceAllowListEnabled
            )
        case .custom:
            let blocksTrackingContent = customTrackingContentScope != .none
            return contentBlockingPreferences(
                category: "custom",
                trackingTable: trackingTable(includingContent: blocksTrackingContent),
                cryptominingEnabled: customBlocksCryptominers,
                fingerprintingEnabled: customBlocksKnownFingerprinters,
                socialTrackingEnabled: true,
                emailTrackingEnabled: false,
                cookieBehavior: customCookieBehavior,
                etpEnabled: true,
                strictListEnabled: false,
                cookiePurgingEnabled: customBlocksRedirectTrackers,
                strictSocialTrackingEnabled: blocksTrackingContent,
                trackingContentScope: customTrackingContentScope,
                suspectedFingerprinterScope: customSuspectedFingerprinterScope,
                bounceTrackingProtectionMode: 2,
                baselineAllowListEnabled: baselineAllowListEnabled,
                convenienceAllowListEnabled: convenienceAllowListEnabled
            )
        case .off:
            return contentBlockingPreferences(
                category: "custom",
                trackingTable: "",
                cryptominingEnabled: false,
                fingerprintingEnabled: false,
                socialTrackingEnabled: false,
                emailTrackingEnabled: false,
                cookieBehavior: 0,
                etpEnabled: false,
                strictListEnabled: false,
                cookiePurgingEnabled: false,
                strictSocialTrackingEnabled: false,
                trackingContentScope: .none,
                suspectedFingerprinterScope: .none,
                bounceTrackingProtectionMode: 2,
                baselineAllowListEnabled: true,
                convenienceAllowListEnabled: true
            )
        }
    }
    
    private func contentBlockingPreferences(
        category: String,
        trackingTable: String,
        cryptominingEnabled: Bool,
        fingerprintingEnabled: Bool,
        socialTrackingEnabled: Bool,
        emailTrackingEnabled: Bool,
        cookieBehavior: Int,
        etpEnabled: Bool,
        strictListEnabled: Bool,
        cookiePurgingEnabled: Bool,
        strictSocialTrackingEnabled: Bool,
        trackingContentScope: CustomBlockingScope,
        suspectedFingerprinterScope: CustomBlockingScope,
        bounceTrackingProtectionMode: Int,
        baselineAllowListEnabled: Bool,
        convenienceAllowListEnabled: Bool
    ) -> [String: Any] {
        return [
            "browser.contentblocking.category": category,
            "urlclassifier.trackingTable": trackingTable,
            "privacy.trackingprotection.cryptomining.enabled": cryptominingEnabled,
            "urlclassifier.features.cryptomining.blacklistTables": cryptominingEnabled ? "base-cryptomining-track-digest256" : "",
            "privacy.trackingprotection.fingerprinting.enabled": fingerprintingEnabled,
            "urlclassifier.features.fingerprinting.blacklistTables": fingerprintingEnabled ? "base-fingerprinting-track-digest256" : "",
            "privacy.socialtracking.block_cookies.enabled": socialTrackingEnabled,
            "urlclassifier.features.socialtracking.annotate.blacklistTables": socialTrackingEnabled ? "social-tracking-protection-facebook-digest256,social-tracking-protection-linkedin-digest256,social-tracking-protection-twitter-digest256" : "",
            "privacy.trackingprotection.emailtracking.enabled": emailTrackingEnabled,
            "urlclassifier.features.emailtracking.blocklistTables": emailTrackingEnabled ? "base-email-track-digest256" : "",
            "network.cookie.cookieBehavior": cookieBehavior,
            "network.cookie.cookieBehavior.pbmode": cookieBehavior,
            "privacy.trackingprotection.annotate_channels": etpEnabled,
            "privacy.annotate_channels.strict_list.enabled": strictListEnabled,
            "privacy.purge_trackers.enabled": cookiePurgingEnabled,
            "privacy.trackingprotection.socialtracking.enabled": strictSocialTrackingEnabled,
            "privacy.trackingprotection.enabled": trackingContentScope == .all,
            "privacy.trackingprotection.pbmode.enabled": trackingContentScope != .none,
            "privacy.fingerprintingProtection": suspectedFingerprinterScope == .all,
            "privacy.fingerprintingProtection.pbmode": suspectedFingerprinterScope != .none,
            "privacy.bounceTrackingProtection.mode": bounceTrackingProtectionMode,
            "privacy.trackingprotection.allow_list.baseline.enabled": baselineAllowListEnabled,
            "privacy.trackingprotection.allow_list.convenience.enabled": convenienceAllowListEnabled,
        ]
    }
    
    private func trackingTable(includingContent: Bool) -> String {
        let base = "moztest-track-simple,ads-track-digest256,analytics-track-digest256,social-track-digest256"
        return includingContent ? "\(base),content-track-digest256" : base
    }
}
