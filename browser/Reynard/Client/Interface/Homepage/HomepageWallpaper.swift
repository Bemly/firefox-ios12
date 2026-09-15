//
//  HomepageWallpaper.swift
//  Reynard
//
//  Created by Minh Ton on 13/8/26.
//

import UIKit

enum HomepageWallpaper {
    private(set) static var image = ImageUtils.image(at: imageURL)
    private static var usesLightForeground = image.map { ImageUtils.usesLightForeground(for: $0) } ?? false
    
    static func foregroundColor(for contentMode: HomepageContentMode) -> UIColor {
        guard !contentMode.isDetached,
              Prefs.HomepageSettings.showsWallpaper,
              image != nil else {
            return .label
        }
        return usesLightForeground ? .white : .black
    }
    
    static func save(_ wallpaper: ImageUtils.JPEGImage) throws {
        try ImageUtils.writeImageData(wallpaper.data, to: imageURL)
        image = UIImage(data: wallpaper.data)
        usesLightForeground = wallpaper.usesLightForeground
        NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
    }
    
    private static var imageURL: URL {
        guard let applicationSupportDirectoryURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory is unavailable")
        }
        return applicationSupportDirectoryURL
            .appendingPathComponent("AppData", isDirectory: true)
            .appendingPathComponent("Homepage", isDirectory: true)
            .appendingPathComponent("Wallpaper.jpg", isDirectory: false)
    }
}
