//
//  NetworkProxySettings.swift
//  Reynard
//
//  Proxy modes mirror Gecko's network.proxy.type values.

enum NetworkProxyMode: Int, CaseIterable {
    // Direct connection, no proxy.
    case direct = 0
    // Manual configuration (custom host + port below).
    case manual = 1
    // Use system proxy settings.
    case system = 5

    var title: String {
        switch self {
        case .direct:
            return "No Proxy"
        case .manual:
            return "Custom Proxy"
        case .system:
            return "System Proxy"
        }
    }

    var subtitle: String {
        switch self {
        case .direct:
            return "Connect directly without a proxy."
        case .manual:
            return "Use the host and port configured below."
        case .system:
            return "Use the proxy configured in iOS Settings."
        }
    }
}
