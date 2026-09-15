//
//  RemoteDebuggingSettingController.swift
//  Reynard
//
//  Created by Minh Ton on 8/9/26.
//

import GeckoView

enum RemoteDebuggingSettingController {
    static func applyRemoteDebugging() {
        let preferences = Prefs.DeveloperSettings.self
        GeckoRuntime.setDefaultPrefs([
            "devtools.debugger.remote-enabled": preferences.remoteDebuggingEnabled,
            "devtools.debugger.remote-port": preferences.remoteDebuggingPort,
            "devtools.chrome.enabled": preferences.remoteDebuggingEnabled,
            
            // TODO: Figure out the chrome toolbox prompt
            "devtools.debugger.prompt-connection": preferences.remoteDebuggingEnabled,
        ])
    }
}
