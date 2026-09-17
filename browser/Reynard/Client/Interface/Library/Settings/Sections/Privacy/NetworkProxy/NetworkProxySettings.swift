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
            return NSLocalizedString("No Proxy", tableName: "SettingsLocalizable", comment: "Proxy mode")
        case .manual:
            return NSLocalizedString("Custom Proxy", tableName: "SettingsLocalizable", comment: "Proxy mode")
        case .system:
            return NSLocalizedString("System Proxy", tableName: "SettingsLocalizable", comment: "Proxy mode")
        }
    }

    var subtitle: String {
        switch self {
        case .direct:
            return NSLocalizedString("Connect directly without a proxy.", tableName: "SettingsLocalizable", comment: "Proxy mode")
        case .manual:
            return NSLocalizedString("Use the host and port configured below.", tableName: "SettingsLocalizable", comment: "Proxy mode")
        case .system:
            return NSLocalizedString("Use the proxy configured in iOS Settings.", tableName: "SettingsLocalizable", comment: "Proxy mode")
        }
    }
}
