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
