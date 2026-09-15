//
//  DNSOverHTTPSPolicyController.swift
//  Reynard
//
//  Created by Minh Ton on 4/9/26.
//

import GeckoView

enum DNSOverHTTPSPolicyController {
    static func applyDNSOverHTTPS() {
        let preferences = Prefs.DNSOverHTTPSPreferences.self
        let selectedProviderURL = preferences.provider.url ?? preferences.customProviderURL
        
        GeckoRuntime.setDefaultPrefs([
            "doh-rollout.enabled": true,
            "network.trr.mode": preferences.protectionLevel.rawValue,
            "network.trr.uri": selectedProviderURL,
            "network.trr.default_provider_uri": SecureDNSProvider.cloudflare.url ?? "",
            "network.trr.excluded-domains": preferences.exceptions.joined(separator: ","),
        ])
    }
}
