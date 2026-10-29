//
//  UIImage+Extension.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import UIKit

extension UIImage {
    /// Fixes image orientation for captured photos
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}

extension UIImage {
    /// Crops the part of this photo that lies under `viewRect` of a `.scaledToFill` preview.
    func cropped(toViewRect viewRect: CGRect, viewSize: CGSize) -> UIImage? {
        guard let cgImage,
              let pixelRect = CropGeometry.imageRect(
                forViewRect: viewRect,
                viewSize: viewSize,
                imageSize: CGSize(width: cgImage.width, height: cgImage.height)),
              let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }
}

extension UIImage {
    /// Same picture with its longer side at most `maxSide` pixels (never enlarges). Renders at scale 1.
    func scaled(toMaxSide maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height) * scale
        guard longest > maxSide else { return self }
        let factor = maxSide / longest
        let target = CGSize(width: (size.width * scale * factor).rounded(), height: (size.height * scale * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Crops a rect given in 0...1 coordinates (top-left origin), independent of the photo's resolution.
    func cropped(toNormalizedRect rect: CGRect) -> UIImage? {
        guard let cgImage else { return nil }
        let pixels = CGRect(x: rect.minX * CGFloat(cgImage.width), y: rect.minY * CGFloat(cgImage.height),
                            width: rect.width * CGFloat(cgImage.width), height: rect.height * CGFloat(cgImage.height))
            .integral.intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard !pixels.isNull, !pixels.isEmpty, let cropped = cgImage.cropping(to: pixels) else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }
}
