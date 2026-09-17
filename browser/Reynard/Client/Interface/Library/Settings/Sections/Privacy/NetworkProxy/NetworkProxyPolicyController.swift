//
//  NetworkProxyPolicyController.swift
//  Reynard
//
//  Pushes the user's proxy choice into Gecko. Called at startup via
//  RuntimePreferences and immediately after every change in the UI.
//  Custom mode reuses the previously verified shape: http/ssl/socks share
//  one host+port (network.proxy.share_proxy_settings).

import GeckoView

enum NetworkProxyPolicyController {
    static func applyProxy() {
        let preferences = Prefs.ProxyPreferences.self

        switch preferences.mode {
        case .direct:
            GeckoRuntime.setDefaultPrefs([
                "network.proxy.type": NetworkProxyMode.direct.rawValue,
            ])
        case .system:
            GeckoRuntime.setDefaultPrefs([
                "network.proxy.type": NetworkProxyMode.system.rawValue,
            ])
        case .manual:
            let host = preferences.customHost
            guard !host.isEmpty else {
                // No host configured yet: stay direct rather than proxying nowhere.
                GeckoRuntime.setDefaultPrefs([
                    "network.proxy.type": NetworkProxyMode.direct.rawValue,
                ])
                return
            }
            let port = preferences.customPort
            GeckoRuntime.setDefaultPrefs([
                "network.proxy.type": NetworkProxyMode.manual.rawValue,
                "network.proxy.share_proxy_settings": true,
                "network.proxy.http": host,
                "network.proxy.http_port": port,
                "network.proxy.ssl": host,
                "network.proxy.ssl_port": port,
                "network.proxy.socks": host,
                "network.proxy.socks_port": port,
                "network.proxy.no_proxies_on": "localhost, 127.0.0.1",
            ])
        }
    }
}
