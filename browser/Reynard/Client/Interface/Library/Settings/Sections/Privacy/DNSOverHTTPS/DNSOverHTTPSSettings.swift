//
//  DNSOverHTTPSSettings.swift
//  Reynard
//
//  Created by Minh Ton on 4/9/26.
//

enum DNSOverHTTPSProtectionLevel: Int, CaseIterable {
    case defaultProtection = 0
    case increasedProtection = 2
    case maxProtection = 3
    case noProtection = 5
}

enum SecureDNSProvider: String, CaseIterable {
    case cloudflare
    case nextDNS
    case custom
    
    var url: String? {
        switch self {
        case .cloudflare:
            return "https://mozilla.cloudflare-dns.com/dns-query"
        case .nextDNS:
            return "https://firefox.dns.nextdns.io/"
        case .custom:
            return nil
        }
    }
}
