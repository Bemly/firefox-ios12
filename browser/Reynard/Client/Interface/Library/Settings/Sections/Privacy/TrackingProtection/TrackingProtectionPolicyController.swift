//
//  TrackingProtectionPolicyController.swift
//  Reynard
//
//  Created by Minh Ton on 22/7/26.
//

import GeckoView

enum TrackingProtectionPolicyController {
    static func applyEnhancedTrackingProtection() {
        let preferences = Prefs.TrackingProtectionPreferences.self
        let baselineAllowListEnabled = preferences.level == .custom
        ? preferences.customBaselineAllowListEnabled
        : preferences.strictBaselineAllowListEnabled
        let convenienceAllowListEnabled = preferences.level == .custom
        ? preferences.customConvenienceAllowListEnabled
        : preferences.strictConvenienceAllowListEnabled
        
        GeckoRuntime.setDefaultPrefs(
            TrackingProtectionPolicy(
                level: preferences.level,
                baselineAllowListEnabled: baselineAllowListEnabled,
                convenienceAllowListEnabled: convenienceAllowListEnabled,
                customCookieBehavior: preferences.customCookiePolicy.rawValue,
                customTrackingContentScope: preferences.customTrackingContentScope,
                customBlocksCryptominers: preferences.customBlocksCryptominers,
                customBlocksKnownFingerprinters: preferences.customBlocksKnownFingerprinters,
                customBlocksRedirectTrackers: preferences.customBlocksRedirectTrackers,
                customSuspectedFingerprinterScope: preferences.customSuspectedFingerprinterScope
            ).preferences
        )
    }
    
    static func applyGlobalPrivacyControl() {
        GeckoRuntime.setDefaultPrefs([
            "privacy.globalprivacycontrol.enabled": Prefs.TrackingProtectionPreferences.globalPrivacyControlEnabled,
            "privacy.globalprivacycontrol.pbmode.enabled": true,
            "privacy.globalprivacycontrol.functionality.enabled": true,
        ])
    }
}
