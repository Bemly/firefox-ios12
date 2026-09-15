//
//  GeckoSessionSettings.swift
//  Reynard
//
//  Created by Minh Ton on 28/6/26.
//

import UIKit

public struct WebsiteModeSetting: Equatable {
    public static let mobile = WebsiteModeSetting(
        userAgentOverride: nil,
        platformOverride: nil,
        appVersionOverride: nil,
        oscpuOverride: nil,
        buildIDOverride: nil,
        userAgentMode: 0,
        viewportMode: 0
    )
    
    public let userAgentOverride: String?
    public let platformOverride: String?
    public let appVersionOverride: String?
    public let oscpuOverride: String?
    public let buildIDOverride: String?
    public let userAgentMode: Int
    public let viewportMode: Int
    
    public init(
        userAgentOverride: String?,
        platformOverride: String?,
        appVersionOverride: String?,
        oscpuOverride: String?,
        buildIDOverride: String?,
        userAgentMode: Int,
        viewportMode: Int
    ) {
        self.userAgentOverride = userAgentOverride
        self.platformOverride = platformOverride
        self.appVersionOverride = appVersionOverride
        self.oscpuOverride = oscpuOverride
        self.buildIDOverride = buildIDOverride
        self.userAgentMode = userAgentMode
        self.viewportMode = viewportMode
    }
}

public struct PageZoomSetting: Equatable {
    public static let `default` = PageZoomSetting(level: 100)
    
    public let level: Int
    
    public var scale: CGFloat {
        return CGFloat(level) / 100
    }
    
    public init(level: Int) {
        self.level = level
    }
}

public struct LanguageSetting: Equatable {
    public static let `default` = LanguageSetting(codes: ["en"])
    
    public let codes: [String]
    
    public var acceptLanguages: String {
        return codes.joined(separator: ",")
    }
    
    public init(codes: [String]) {
        self.codes = codes
    }
}

public struct GeckoSessionSettings: Equatable {
    public static let `default` = GeckoSessionSettings(
        websiteMode: .mobile,
        pageZoom: .default,
        language: .default
    )
    
    public let websiteMode: WebsiteModeSetting
    public let pageZoom: PageZoomSetting
    public let language: LanguageSetting
    
    public init(
        websiteMode: WebsiteModeSetting,
        pageZoom: PageZoomSetting,
        language: LanguageSetting
    ) {
        self.websiteMode = websiteMode
        self.pageZoom = pageZoom
        self.language = language
    }
}
