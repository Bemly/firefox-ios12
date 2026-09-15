//
//  TabState.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import GeckoView

enum TabLoadingState: Equatable {
    case idle
    case loading(progress: Float)
    
    var isLoading: Bool {
        switch self {
        case .idle:
            return false
        case .loading:
            return true
        }
    }
    
    var progress: Float {
        switch self {
        case .idle:
            return 0
        case let .loading(progress):
            return progress
        }
    }
}

enum TabRestoreState: Equatable {
    case none
    case pendingSession
    case pendingURL(String)
}

enum TabDisplayState: Equatable {
    case committed
    case pending(String)
}

enum TabInsertionTarget: Equatable {
    case end
    case afterSelected
    case index(Int)
}

enum HistoryNavigationDirection {
    case back
    case forward
}

final class TabSessionState {
    var tabSessionState: GeckoSessionState?
    var restoreState: TabRestoreState = .none
    var suppressInitialNavigation = true
    var isSuppressingInitialBlankPageLoad = false
    var sessionNavigationAvailability = SessionNavigationAvailability.unavailable
    var navigationState = NavigationAvailability(canGoBack: false, canGoForward: false)
    var pendingHistoryNavigations: [HistoryNavigationDirection] = []
    var lastHistoryNavigationID = 0
    var activeHistoryNavigationID: Int?
    var preparedNavigationThumbnailURL: String?
    var displayState: TabDisplayState = .committed
    var loadingState = TabLoadingState.idle
    var showsStartupHomepage = false
    var selectionOrder = 0
}
