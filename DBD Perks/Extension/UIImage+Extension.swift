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
    /// Crop an image using a visible overlay area (in view coordinates)
    func centerCropped(to overlaySize: CGSize, sizeInView viewSize: CGSize) -> UIImage {
        let imageAspect = size.width / size.height
        let viewAspect = viewSize.width / viewSize.height

        var scaleFactor: CGFloat
        var scaledImageSize = CGSize.zero

        // Because preview uses `.scaledToFill()`
        if imageAspect > viewAspect {
            // Image is wider — scaled to match height
            scaleFactor = size.height / viewSize.height
            scaledImageSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        } else {
            // Image is taller — scaled to match width
            scaleFactor = size.width / viewSize.width
            scaledImageSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        }

        // Compute overlay rect in image coordinates
        let cropWidth = overlaySize.width * scaleFactor
        let cropHeight = overlaySize.height * scaleFactor
        let cropX = (size.width - cropWidth) / 2
        let cropY = (size.height - cropHeight) / 2
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)

        guard let cgImage = cgImage?.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}

