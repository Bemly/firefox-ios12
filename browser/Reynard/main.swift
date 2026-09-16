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
// over the process. 见 AGENTS.md“iOS 12 兼容门禁清单”.
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

private func configureSandboxExtension() {
    guard let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return
    }

    typealias IssueFileExtension = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UInt32) -> UnsafeMutablePointer<CChar>?

    // I can't seem to find any public documentation for these stuff on iOS?
    // Also I'm surprised that this works on iOS
    // https://github.com/WebKit/WebKit/blob/main/Source/WTF/wtf/spi/darwin/SandboxSPI.h
    // https://github.com/WebKit/WebKit/blob/main/Source/WebKit/Shared/Cocoa/SandboxExtensionCocoa.mm
    guard let sandboxHandle = dlopen("/usr/lib/system/libsystem_sandbox.dylib", RTLD_LAZY),
          let symbol = dlsym(sandboxHandle, "sandbox_extension_issue_file") else {
        return
    }

    let issueFileExtension = unsafeBitCast(symbol, to: IssueFileExtension.self)
    let extensionClass = "com.apple.app-sandbox.read"

    guard let token = extensionClass.withCString({ extensionClassPointer in
        documentsDirectoryURL.path.withCString { pathPointer in
            issueFileExtension(extensionClassPointer, pathPointer, 0)
        }
    }) else {
        return
    }

    let tokenString = String(cString: token)
    free(UnsafeMutableRawPointer(token))
    setenv("MOZ_DOCUMENTS_SANDBOX_EXTENSION", tokenString, 1)
}

LocalizationBundle.activate()
// Also start the JIT controller on iOS 12. This port is single-process, so
// JITController additionally tries the ptrace helper against the MAIN process
// itself (see JITController.start()). Deliberately silent on failure; the JS
// benchmark page is the arbiter.
JITController.shared.start()
// configureUnsandboxedAppDataDirectories is available on iOS 13.x only (introduced 13.0,
// obsoleted 14.0); narrow the guard so it isn't called on iOS 12. 见 AGENTS.md“iOS 12 兼容门禁清单”.
if #available(iOS 13.0, *) {
    if #unavailable(iOS 14.0),
       getEntitlementValue("com.apple.private.security.no-sandbox") {
        configureUnsandboxedAppDataDirectories()
    }
}

configureSandboxExtension()

if #available(iOS 13.0, *) {
    _ = NotificationCenter.default.addObserver(forName: Notification.Name("GeckoView.BuildMenu"), object: nil, queue: .main) { notification in
        guard let builder = notification.object as? UIMenuBuilder else { return }
        ApplicationMenuBuilder.build(with: builder)
    }
}

GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
