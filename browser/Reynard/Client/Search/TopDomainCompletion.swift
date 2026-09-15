//
//  TopDomainCompletion.swift
//  Reynard
//
//  Created by Minh Ton on 23/7/26.
//

import Foundation

final class TopDomainCompletion {
    private struct Dataset: Decodable {
        let domains: [String]
    }
    
    private lazy var domains: [String] = {
        guard let url = Bundle.main.url(forResource: "TopDomains", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dataset = try? PropertyListDecoder().decode(Dataset.self, from: data) else {
            return []
        }
        
        return dataset.domains
    }()
    
    func completions(for query: String, limit: Int) -> [String] {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedQuery.isEmpty, limit > 0 else {
            return []
        }
        
        return Array(domains.lazy.filter {
            $0.range(of: normalizedQuery, options: [.anchored, .caseInsensitive]) != nil
        }.prefix(limit))
    }
}
