//
//  main.swift
//  Reynard
//
//  Created by Minh Ton on 1/2/26.
//

import Foundation
import GeckoView
import UIKit
import Darwin

@available(iOS, introduced: 13.0, obsoleted: 14.0)
private func configureUnsandboxedAppDataDirectories() {
    guard let cachesDirectory = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    ).first else {
        return
    }
    
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
        return
    }
    
    let appDataDirectory = cachesDirectory
        .appendingPathComponent(bundleIdentifier, isDirectory: true)
        .appendingPathComponent(".mozilla", isDirectory: true)
        .appendingPathComponent("firefox", isDirectory: true)
    
    do {
        try FileManager.default.createDirectory(
            at: appDataDirectory,
            withIntermediateDirectories: true
        )
    } catch {
        return
    }
    
    setenv("MOZ_APP_DATA", appDataDirectory.path, 1)
    setenv("MOZ_LOCAL_APP_DATA", appDataDirectory.path, 1)
}

// On iOS 12 there is no UIScene, so SceneDelegate never runs, and the engine's
// AppShellDelegate (the actual UIApplication delegate) never creates a window.
// Create the browser window ourselves when UIKit finishes launching. UIKit posts
// this notification regardless of which app delegate is used, and the observer
// must be registered before UIApplicationMain (inside GeckoRuntime.main) takes
// over the process. See IOS12_GATES.md.
private var legacyRootWindow: UIWindow?
if #unavailable(iOS 13.0) {
    NotificationCenter.default.addObserver(
        forName: UIApplication.didFinishLaunchingNotification,
        object: nil,
        queue: .main
    ) { _ in
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = BrowserViewController()
        window.makeKeyAndVisible()
        legacyRootWindow = window
    }
}

UserDataMigration.shared.run()
// Experiment (local/jit-main-process-a7): also start the JIT controller on
// iOS 12. This port is single-process, so JITController additionally tries the
// ptrace helper against the MAIN process itself (see JITController.start()).
// Deliberately silent on failure; the JS benchmark page is the arbiter.
JITController.shared.start()
// configureUnsandboxedAppDataDirectories is available on iOS 13.x only (introduced 13.0,
// obsoleted 14.0); narrow the guard so it isn't called on iOS 12. See IOS12_GATES.md.
if #available(iOS 13.0, *) {
    if #unavailable(iOS 14.0),
       getEntitlementValue("com.apple.private.security.no-sandbox") {
        configureUnsandboxedAppDataDirectories()
    }
}
GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
