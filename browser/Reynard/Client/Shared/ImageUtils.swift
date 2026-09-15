//
//  ImageUtils.swift
//  Reynard
//
//  Created by Minh Ton on 13/8/26.
//

import ImageIO
import UIKit

enum ImageUtils {
    struct JPEGImage: Sendable {
        let data: Data
        let usesLightForeground: Bool
    }
    
    static func image(at url: URL) -> UIImage? {
        return UIImage(contentsOfFile: url.path)
    }
    
    static func writeImageData(
        _ imageData: Data,
        to url: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try imageData.write(to: url, options: .atomic)
    }
    
    static nonisolated func prepareJPEGImage(
        from sourceData: Data,
        maximumPixelSize: Int,
        compressionQuality: CGFloat = 0.9,
        lightForegroundLuminanceThreshold: CGFloat = 0.32
    ) -> JPEGImage? {
        guard maximumPixelSize > 0,
              let imageSource = CGImageSourceCreateWithData(sourceData as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                imageSource,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                    kCGImageSourceShouldCacheImmediately: true,
                ] as CFDictionary
              ).map({ UIImage(cgImage: $0) }),
              let data = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        
        return JPEGImage(
            data: data,
            usesLightForeground: usesLightForeground(
                for: image,
                luminanceThreshold: lightForegroundLuminanceThreshold
            )
        )
    }
    
    static nonisolated func usesLightForeground(
        for image: UIImage,
        luminanceThreshold: CGFloat = 0.32
    ) -> Bool {
        guard let cgImage = image.cgImage else {
            return false
        }
        
        let size = 32
        var pixels = [UInt8](repeating: 0, count: size * size)
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
              let context = CGContext(data: &pixels, width: size, height: size, bitsPerComponent: 8,
                                      bytesPerRow: size, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return false
        }
        
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        
        let luminanceTotal = pixels.reduce(0) { $0 + Int($1) }
        let averageLuminance = CGFloat(luminanceTotal) / CGFloat(pixels.count * 255)
        return averageLuminance < luminanceThreshold
    }
}
