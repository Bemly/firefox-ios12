//
//  UserAgentPolicy.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import Foundation
import GeckoView

// MARK: - User Agent Configuration

struct UserAgentConfiguration {
    let override: String?
    let platformOverride: String?
    let appVersionOverride: String?
    let oscpuOverride: String?
    let buildIDOverride: String?
    let forcesMobileMode: Bool
}

struct UserAgentPolicy {
    // MARK: - Policy Resolution
    
    func configuration(for url: String, prefersDesktopMode: Bool) -> UserAgentConfiguration {
        let host = DomainMatcher.host(from: url)
        let geckoMajorVersion = GeckoRuntime.version.split(whereSeparator: { !$0.isNumber }).first.map(String.init) ?? "0"
        let chromeMajorVersion = (Int(geckoMajorVersion) ?? 0) + 4
        let mobileConfiguration = defaultConfiguration(prefersDesktopMode: false)
        let selectedConfiguration = defaultConfiguration(prefersDesktopMode: prefersDesktopMode)
        
        let googleMobileUserAgent = "Mozilla/5.0 (Linux; Android 15; Nexus 5 Build/MRA58N) FxQuantum/\(geckoMajorVersion).0 AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(chromeMajorVersion).0.0.0 Mobile Safari/537.36"
        
        // Always use the Android mobile user agent for AMO to
        // allow addons installation.
        if host == "addons.mozilla.org" {
            return defaultConfiguration(prefersDesktopMode: false, forcesMobileMode: true)
        }
        
        // Addon setting pages also require the Android user agent to work properly.
        if url.starts(with: "moz-extension://") {
            return defaultConfiguration(prefersDesktopMode: false, forcesMobileMode: true)
        }
        
        // I have so many people reporting broken UI issues, login
        // issues, etc on Google services, so this is a compatibility
        // hack stolen from the Google Search Fixer extension.
        if Prefs.CompatibilitySettings.useAndroidUserAgent && !prefersDesktopMode,
           host?.split(separator: ".").contains("google") == true {
            return compatibilityConfiguration(
                using: mobileConfiguration,
                forcesMobileMode: false,
                userAgentOverride: googleMobileUserAgent
            )
        }
        
        let usesAndroidUserAgent = Prefs.CompatibilitySettings.useAndroidUserAgent || (host.map { host in
            Prefs.CompatibilitySettings.androidUserAgentDomains.contains { DomainMatcher.matches(host: host, domain: $0) }
        } ?? false)
        
        guard usesAndroidUserAgent else {
            return UserAgentConfiguration(
                override: nil,
                platformOverride: nil,
                appVersionOverride: nil,
                oscpuOverride: nil,
                buildIDOverride: nil,
                forcesMobileMode: false
            )
        }
        return compatibilityConfiguration(using: selectedConfiguration, forcesMobileMode: false)
    }
    
    func defaultConfiguration(
        prefersDesktopMode: Bool,
        forcesMobileMode: Bool = false
    ) -> UserAgentConfiguration {
        let geckoMajorVersion = GeckoRuntime.version.split(whereSeparator: { !$0.isNumber }).first.map(String.init) ?? "0"
        
        // It's sad to have the Android UA, because Gecko + iOS
        // is a super weird combination that websites don't expect!
        let androidMobileUserAgent = "Mozilla/5.0 (Android 15; Mobile; rv:\(geckoMajorVersion).0) Gecko/\(geckoMajorVersion).0 Firefox/\(geckoMajorVersion).0"
        let androidDesktopUserAgent = "Mozilla/5.0 (X11; Linux x86_64; rv:\(geckoMajorVersion).0) Gecko/20100101 Firefox/\(geckoMajorVersion).0"
        let androidMobilePlatform = "Linux armv81"
        let androidDesktopPlatform = "Linux x86_64"
        let androidMobileAppVersion = "5.0 (Android 15)"
        let androidDesktopAppVersion = "5.0 (X11)"
        
        let userAgent = prefersDesktopMode ? androidDesktopUserAgent : androidMobileUserAgent
        let platform = prefersDesktopMode ? androidDesktopPlatform : androidMobilePlatform
        let appVersion = prefersDesktopMode ? androidDesktopAppVersion : androidMobileAppVersion
        return UserAgentConfiguration(
            override: userAgent,
            platformOverride: platform,
            appVersionOverride: appVersion,
            oscpuOverride: platform,
            buildIDOverride: nil,
            forcesMobileMode: forcesMobileMode
        )
    }
    
    private func compatibilityConfiguration(
        using configuration: UserAgentConfiguration,
        forcesMobileMode: Bool,
        userAgentOverride: String? = nil
    ) -> UserAgentConfiguration {
        let customUserAgent = Prefs.CompatibilitySettings.customUserAgent
        let customPlatform = Prefs.CompatibilitySettings.customPlatform
        let customAppVersion = Prefs.CompatibilitySettings.customAppVersion
        let customOscpu = Prefs.CompatibilitySettings.customOscpu
        let customBuildID = Prefs.CompatibilitySettings.customBuildID
        return UserAgentConfiguration(
            override: customUserAgent.isEmpty ? userAgentOverride ?? configuration.override : customUserAgent,
            platformOverride: customPlatform.isEmpty ? configuration.platformOverride : customPlatform,
            appVersionOverride: customAppVersion.isEmpty ? configuration.appVersionOverride : customAppVersion,
            oscpuOverride: customOscpu.isEmpty ? configuration.oscpuOverride : customOscpu,
            buildIDOverride: customBuildID.isEmpty ? nil : customBuildID,
            forcesMobileMode: forcesMobileMode
        )
    }
}
