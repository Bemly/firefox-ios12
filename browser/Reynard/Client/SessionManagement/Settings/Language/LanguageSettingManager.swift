//
//  LanguageSettingManager.swift
//  Reynard
//
//  Created by Minh Ton on 11/7/26.
//

import Foundation
import GeckoView

final class LanguageSettingManager {
    func setting() -> LanguageSetting {
        return LanguageSetting(codes: Prefs.LanguageSettings.websiteLanguages)
    }
}
