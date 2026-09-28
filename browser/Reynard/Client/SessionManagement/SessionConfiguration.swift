//
//  SessionConfiguration.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import GeckoView

enum SessionOpening {
    case immediate(windowID: String?)
    case manual
    case external
}

struct SessionDelegates {
    var content: ContentDelegate?
    var navigation: NavigationDelegate?
    var history: HistoryDelegate?
    var permission: PermissionEmbedderDelegate?
    var progress: ProgressDelegate?
    var scroll: ScrollDelegate?
    var prompt: PromptDelegate?
    var print: PrintDelegate?
    var selectionAction: SelectionActionDelegate?
    var mediaSession: MediaSessionDelegate?
    
    init(
        content: ContentDelegate? = nil,
        navigation: NavigationDelegate? = nil,
        history: HistoryDelegate? = nil,
        permission: PermissionEmbedderDelegate? = nil,
        progress: ProgressDelegate? = nil,
        scroll: ScrollDelegate? = nil,
        prompt: PromptDelegate? = nil,
        print: PrintDelegate? = nil,
        selectionAction: SelectionActionDelegate? = nil,
        mediaSession: MediaSessionDelegate? = nil
    ) {
        self.content = content
        self.navigation = navigation
        self.history = history
        self.permission = permission
        self.progress = progress
        self.scroll = scroll
        self.prompt = prompt
        self.print = print
        self.selectionAction = selectionAction
        self.mediaSession = mediaSession
    }
}
