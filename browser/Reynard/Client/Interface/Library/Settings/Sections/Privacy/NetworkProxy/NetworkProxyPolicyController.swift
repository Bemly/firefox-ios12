//
//  NetworkProxyPolicyController.swift
//  Reynard
//
//  Pushes the user's proxy choice into Gecko. Called at startup via
//  RuntimePreferences and immediately after every change in the UI.
//  Custom mode reuses the previously verified shape: http/ssl/socks share
//  one host+port (network.proxy.share_proxy_settings).

import CFNetwork
import Foundation
import GeckoView

enum NetworkProxyPolicyController {
    static func applyProxy() {
        let preferences = Prefs.ProxyPreferences.self

        switch preferences.mode {
        case .direct:
            applyDirect()
        case .system:
            // Gecko has no system-proxy backend on iOS (no
            // @mozilla.org/system-proxy-settings;1 implementation; type 5 would
            // silently fall back to direct). Bridge it ourselves: read the
            // current iOS Wi-Fi proxy and push it as a manual config.
            if let system = currentSystemProxy() {
                applyManual(host: system.host, port: system.port)
            } else {
                applyDirect()
            }
        case .manual:
            let host = preferences.customHost
            guard !host.isEmpty else {
                // No host configured yet: stay direct rather than proxying nowhere.
                applyDirect()
                return
            }
            applyManual(host: host, port: preferences.customPort)
        }
    }

    private static func applyDirect() {
        GeckoRuntime.setDefaultPrefs([
            "network.proxy.type": NetworkProxyMode.direct.rawValue,
        ])
    }

    private static func applyManual(host: String, port: Int) {
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

    /// Reads the iOS system proxy (current Wi-Fi network) via CFNetwork.
    /// Returns nil when no HTTP proxy is configured.
    /// NOTE: SCDynamicStoreCopyProxies is macOS-only ('unavailable in iOS'),
    /// CFNetworkCopySystemProxySettings is the iOS-capable equivalent.
    static func currentSystemProxy() -> (host: String, port: Int)? {
        guard let proxies = CFNetworkCopySystemProxySettings() as? [String: Any] else {
            return nil
        }
        let enabled = (proxies[kCFNetworkProxiesHTTPEnable as String] as? Int ?? 0) != 0
        guard enabled,
              let host = proxies[kCFNetworkProxiesHTTPProxy as String] as? String,
              !host.isEmpty,
              let port = proxies[kCFNetworkProxiesHTTPPort as String] as? Int,
              port > 0, port <= 65535 else {
            return nil
        }
        return (host, port)
    }
}
