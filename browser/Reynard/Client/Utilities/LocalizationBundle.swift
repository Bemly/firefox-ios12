//
//  LocalizationBundle.swift
//  Reynard
//
//  Created by Minh Ton on 23/8/26.
//

import Foundation
import ObjectiveC

final class LocalizationBundle: Bundle, @unchecked Sendable {
    static func activate() {
        object_setClass(Bundle.main, LocalizationBundle.self)
    }
    
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        let localizedString = super.localizedString(forKey: key, value: value, table: tableName)
        guard localizedString.isEmpty else {
            return localizedString
        }
        
        guard let value, !value.isEmpty else {
            return key
        }
        
        return value
    }
}
