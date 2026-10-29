//
//  PerkImageProcessor.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML

final class PerkImageProcessor {
    private let context = CIContext()

    /// Preprocess image: resize to the model input size, keeping RGB colors.
    /// The model was trained on RGB icons and normalizes (scale 1/255) internally,
    /// so no grayscale or color filtering is applied here.
    func preprocess(_ image: UIImage, targetSize: CGSize = CGSize(width: 128, height: 128)) -> CVPixelBuffer? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let scaleX = targetSize.width / ciImage.extent.width
        let scaleY = targetSize.height / ciImage.extent.height
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        return pixelBuffer(from: resized, context: context, size: targetSize)
    }

    /// Convert CIImage → CVPixelBuffer
    private func pixelBuffer(from ciImage: CIImage, context: CIContext, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary

        let width = Int(size.width)
        let height = Int(size.height)
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }

        context.render(ciImage, to: buffer)
        return buffer
    }
}
