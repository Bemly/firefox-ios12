//
//  HTTPSOnlyModePolicyController.swift
//  Reynard
//
//  Created by Minh Ton on 23/7/26.
//

import GeckoView

enum HTTPSOnlyModePolicyController {
    static func applyHTTPSOnlyMode() {
        let preferences = Prefs.HTTPSOnlyModePreferences.self
        let enabledInAllTabs = preferences.enabled && preferences.scope == .allTabs
        let enabledInPrivateTabs = preferences.enabled && preferences.scope == .privateTabs
        GeckoRuntime.setDefaultPrefs([
            "dom.security.https_only_mode": enabledInAllTabs,
            "dom.security.https_only_mode_pbm": enabledInPrivateTabs,
        ])
    }
}
