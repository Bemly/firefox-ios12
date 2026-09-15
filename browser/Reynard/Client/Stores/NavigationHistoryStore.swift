//
//  NavigationHistoryStore.swift
//  Reynard
//
//  Created by Minh Ton on 17/5/26.
//

import Foundation
import UIKit

final class NavigationHistoryStore {
    static let shared = NavigationHistoryStore()
    
    struct HistoryItem {
        let title: String
        let url: String
    }
    
    struct State {
        let canGoBack: Bool
        let canGoForward: Bool
        let usesStoredHistory: Bool
    }
    
    struct Snapshot {
        let canGoBack: Bool
        let canGoForward: Bool
        let backHistory: [HistoryItem]
        let forwardHistory: [HistoryItem]
        let backPreviewImage: UIImage?
        let forwardPreviewImage: UIImage?
        let usesStoredHistory: Bool
    }
    
    nonisolated private struct NavigationEntry: Codable, Sendable {
        let id: UUID
        var url: String
        var title: String
        var thumbnailData: Data?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case url
            case title
            case thumbnailData
        }
        
        init(
            id: UUID = UUID(),
            url: String,
            title: String,
            thumbnailData: Data?
        ) {
            self.id = id
            self.url = url
            self.title = title
            self.thumbnailData = thumbnailData
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            url = try container.decode(String.self, forKey: .url)
            title = try container.decode(String.self, forKey: .title)
            thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData)
        }
    }
    
    nonisolated private struct StoredHistory: Codable, Sendable {
        var currentEntryID: UUID?
        var currentURL: String?
        var currentTitle: String?
        var currentThumbnailData: Data?
        var backHistory: [NavigationEntry]
        var forwardHistory: [NavigationEntry]
        var usesStoredHistory: Bool?
        
        private enum CodingKeys: String, CodingKey {
            case currentEntryID = "currentID"
            case currentURL
            case currentTitle
            case currentThumbnailData = "currentThumbnail"
            case backHistory = "backList"
            case forwardHistory = "forwardList"
            case usesStoredHistory = "ownsNav"
        }
        
        init(
            currentEntryID: UUID?,
            currentURL: String?,
            currentTitle: String?,
            currentThumbnailData: Data?,
            backHistory: [NavigationEntry],
            forwardHistory: [NavigationEntry],
            usesStoredHistory: Bool?
        ) {
            self.currentEntryID = currentEntryID
            self.currentURL = currentURL
            self.currentTitle = currentTitle
            self.currentThumbnailData = currentThumbnailData
            self.backHistory = backHistory
            self.forwardHistory = forwardHistory
            self.usesStoredHistory = usesStoredHistory
        }
    }
    
    private let thumbnailJPEGQuality = 0.7
    private let persistenceDelay: DispatchTimeInterval = .milliseconds(100)
    private let fileManager: FileManager
    private let storageURL: URL
    private let queue = DispatchQueue(label: "com.minh-ton.Reynard.NavigationHistoryStore.Queue", qos: .userInitiated)
    private let thumbnailQueue = DispatchQueue(label: "com.minh-ton.Reynard.NavigationHistoryStore.ThumbnailQueue", qos: .utility)
    private let persistenceQueue = DispatchQueue(label: "com.minh-ton.Reynard.NavigationHistoryStore.PersistenceQueue", qos: .utility)
    private var historyCache: [UUID: StoredHistory] = [:]
    private var pendingHistories: [UUID: StoredHistory] = [:]
    private var isPersistenceScheduled = false
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        guard let applicationSupportDirectoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory is unavailable")
        }
        
        self.storageURL = applicationSupportDirectoryURL
            .appendingPathComponent("AppData", isDirectory: true)
            .appendingPathComponent("TabSessions", isDirectory: true)
        
        queue.sync {
            createStorageDirectory()
        }
    }
    
    func currentSnapshot(for tabID: UUID) -> Snapshot {
        queue.sync {
            let history = loadHistory(for: tabID)
            return snapshot(from: history)
        }
    }
    
    func currentState(for tabID: UUID) -> State {
        queue.sync {
            let history = loadHistory(for: tabID)
            return State(
                canGoBack: !history.backHistory.isEmpty,
                canGoForward: !history.forwardHistory.isEmpty,
                usesStoredHistory: history.usesStoredHistory ?? false
            )
        }
    }
    
    func currentPreviewImages(for tabID: UUID) -> NavigationPreviewImages {
        queue.sync {
            let history = loadHistory(for: tabID)
            return NavigationPreviewImages(
                backImage: history.backHistory.last?.thumbnailData.flatMap(UIImage.init(data:)),
                forwardImage: history.forwardHistory.first?.thumbnailData.flatMap(UIImage.init(data:))
            )
        }
    }
    
    func recordNavigation(to url: String, title: String, for tabID: UUID) {
        queue.sync {
            var history = loadHistory(for: tabID)
            guard history.currentURL != url else {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedTitle.isEmpty,
                   history.currentTitle != trimmedTitle {
                    history.currentTitle = trimmedTitle
                    saveHistory(history, for: tabID)
                }
                return
            }
            let normalizedTitle = normalizedTitle(title, fallback: url)
            
            if let currentURL = history.currentURL,
               !currentURL.isEmpty {
                history.backHistory.append(NavigationEntry(
                    id: history.currentEntryID ?? UUID(),
                    url: currentURL,
                    title: history.currentTitle ?? currentURL,
                    thumbnailData: history.currentThumbnailData
                ))
            }
            
            history.currentEntryID = UUID()
            history.currentURL = url
            history.currentTitle = normalizedTitle
            history.currentThumbnailData = nil
            history.forwardHistory.removeAll(keepingCapacity: false)
            saveHistory(history, for: tabID)
        }
    }
    
    func setUsesPersistedHistory(_ usesPersistedHistory: Bool, for tabID: UUID) {
        queue.sync {
            var history = loadHistory(for: tabID)
            history.usesStoredHistory = usesPersistedHistory
            saveHistory(history, for: tabID)
        }
    }
    
    func goBack(to index: Int, for tabID: UUID) -> String? {
        queue.sync {
            var history = loadHistory(for: tabID)
            guard index >= 0,
                  index < history.backHistory.count else {
                return nil
            }
            
            let targetIndex = history.backHistory.count - index - 1
            let target = history.backHistory[targetIndex]
            let firstForwardIndex = targetIndex + 1
            var movedEntries = firstForwardIndex < history.backHistory.count
            ? Array(history.backHistory[firstForwardIndex...])
            : []
            if let currentURL = history.currentURL,
               !currentURL.isEmpty {
                movedEntries.append(NavigationEntry(
                    id: history.currentEntryID ?? UUID(),
                    url: currentURL,
                    title: history.currentTitle ?? currentURL,
                    thumbnailData: history.currentThumbnailData
                ))
            }
            
            history.backHistory.removeLast(index + 1)
            history.forwardHistory = movedEntries + history.forwardHistory
            history.currentEntryID = target.id
            history.currentURL = target.url
            history.currentTitle = target.title
            history.currentThumbnailData = target.thumbnailData
            saveHistory(history, for: tabID)
            return target.url
        }
    }
    
    func goForward(to index: Int, for tabID: UUID) -> String? {
        queue.sync {
            var history = loadHistory(for: tabID)
            guard index >= 0,
                  index < history.forwardHistory.count else {
                return nil
            }
            
            let target = history.forwardHistory[index]
            let movedEntries = Array(history.forwardHistory.prefix(index))
            if let currentURL = history.currentURL,
               !currentURL.isEmpty {
                history.backHistory.append(NavigationEntry(
                    id: history.currentEntryID ?? UUID(),
                    url: currentURL,
                    title: history.currentTitle ?? currentURL,
                    thumbnailData: history.currentThumbnailData
                ))
            }
            history.backHistory.append(contentsOf: movedEntries)
            history.forwardHistory.removeFirst(index + 1)
            history.currentEntryID = target.id
            history.currentURL = target.url
            history.currentTitle = target.title
            history.currentThumbnailData = target.thumbnailData
            saveHistory(history, for: tabID)
            return target.url
        }
    }
    
    func updateCurrentHistoryTitle(_ title: String, for tabID: UUID, matching url: String) {
        queue.sync {
            var history = self.loadHistory(for: tabID)
            guard history.currentURL == url else {
                return
            }
            
            let normalizedTitle = self.normalizedTitle(title, fallback: url)
            guard history.currentTitle != normalizedTitle else {
                return
            }
            
            history.currentTitle = normalizedTitle
            self.saveHistory(history, for: tabID)
        }
    }
    
    func updateCurrentHistoryThumbnail(
        _ image: UIImage?,
        for tabID: UUID,
        matching url: String,
        completion: @escaping () -> Void
    ) {
        queue.async {
            var history = self.loadHistory(for: tabID)
            guard history.currentURL == url else {
                return
            }
            
            let entryID = history.currentEntryID ?? UUID()
            if history.currentEntryID == nil {
                history.currentEntryID = entryID
                self.saveHistory(history, for: tabID)
            }
            
            self.thumbnailQueue.async {
                let thumbnailData = image?.jpegData(compressionQuality: self.thumbnailJPEGQuality)
                self.queue.async {
                    var history = self.loadHistory(for: tabID)
                    guard self.updateThumbnailData(thumbnailData, for: entryID, in: &history) else {
                        return
                    }
                    
                    self.saveHistory(history, for: tabID)
                    DispatchQueue.main.async(execute: completion)
                }
            }
        }
    }
    
    func flushPendingWrites() {
        queue.sync {}
        thumbnailQueue.sync {}
        let pendingHistories = queue.sync {
            takePendingHistories()
        }
        persistenceQueue.sync {
            persist(pendingHistories)
        }
    }
    
    func invalidateThumbnails() {
        queue.sync {
            let fileURLs = (try? self.fileManager.contentsOfDirectory(
                at: self.storageURL,
                includingPropertiesForKeys: nil
            )) ?? []
            let storedTabIDs = fileURLs.compactMap { UUID(uuidString: $0.lastPathComponent) }
            let tabIDs = Set(storedTabIDs).union(self.historyCache.keys)
            
            tabIDs.forEach { tabID in
                var history = self.loadHistory(for: tabID)
                history.currentThumbnailData = nil
                history.backHistory = history.backHistory.map {
                    var entry = $0
                    entry.thumbnailData = nil
                    return entry
                }
                history.forwardHistory = history.forwardHistory.map {
                    var entry = $0
                    entry.thumbnailData = nil
                    return entry
                }
                self.saveHistory(history, for: tabID)
            }
        }
    }
    
    func removeNavigationHistory(for tabID: UUID) {
        queue.async {
            self.historyCache.removeValue(forKey: tabID)
            self.pendingHistories.removeValue(forKey: tabID)
            let fileURL = self.historyURL(for: tabID)
            self.persistenceQueue.async {
                try? self.fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    private func createStorageDirectory() {
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }
    
    private func loadHistory(for tabID: UUID) -> StoredHistory {
        if let history = historyCache[tabID] {
            return history
        }
        
        let history: StoredHistory
        if let data = try? Data(contentsOf: historyURL(for: tabID)),
           let decoded = try? JSONDecoder().decode(StoredHistory.self, from: data) {
            history = decoded
        } else {
            history = StoredHistory(
                currentEntryID: nil,
                currentURL: nil,
                currentTitle: nil,
                currentThumbnailData: nil,
                backHistory: [],
                forwardHistory: [],
                usesStoredHistory: nil
            )
        }
        
        historyCache[tabID] = history
        return history
    }
    
    private func saveHistory(_ history: StoredHistory, for tabID: UUID) {
        historyCache[tabID] = history
        pendingHistories[tabID] = history
        guard !isPersistenceScheduled else {
            return
        }
        
        isPersistenceScheduled = true
        persistenceQueue.asyncAfter(deadline: .now() + persistenceDelay) {
            let pendingHistories = self.queue.sync {
                self.takePendingHistories()
            }
            self.persist(pendingHistories)
        }
    }
    
    private func takePendingHistories() -> [(UUID, StoredHistory)] {
        isPersistenceScheduled = false
        let histories = Array(pendingHistories)
        pendingHistories.removeAll()
        return histories
    }
    
    private func persist(_ histories: [(UUID, StoredHistory)]) {
        histories.forEach { tabID, history in
            guard let data = try? JSONEncoder().encode(history) else {
                return
            }
            
            try? data.write(to: historyURL(for: tabID), options: .atomic)
        }
    }
    
    private func updateThumbnailData(_ thumbnailData: Data?, for entryID: UUID, in history: inout StoredHistory) -> Bool {
        if history.currentEntryID == entryID {
            history.currentThumbnailData = thumbnailData
            return true
        }
        
        if let index = history.backHistory.firstIndex(where: { $0.id == entryID }) {
            history.backHistory[index].thumbnailData = thumbnailData
            return true
        }
        
        if let index = history.forwardHistory.firstIndex(where: { $0.id == entryID }) {
            history.forwardHistory[index].thumbnailData = thumbnailData
            return true
        }
        
        return false
    }
    
    private func snapshot(from history: StoredHistory) -> Snapshot {
        Snapshot(
            canGoBack: !history.backHistory.isEmpty,
            canGoForward: !history.forwardHistory.isEmpty,
            backHistory: history.backHistory.reversed().map(historyItem(from:)),
            forwardHistory: history.forwardHistory.map(historyItem(from:)),
            backPreviewImage: history.backHistory.last?.thumbnailData.flatMap(UIImage.init(data:)),
            forwardPreviewImage: history.forwardHistory.first?.thumbnailData.flatMap(UIImage.init(data:)),
            usesStoredHistory: history.usesStoredHistory ?? false
        )
    }
    
    private func historyItem(from entry: NavigationEntry) -> HistoryItem {
        HistoryItem(title: entry.title, url: entry.url)
    }
    
    private func normalizedTitle(_ title: String, fallback: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? fallback : trimmedTitle
    }
    
    private func historyURL(for tabID: UUID) -> URL {
        storageURL.appendingPathComponent(tabID.uuidString, isDirectory: false)
    }
}
