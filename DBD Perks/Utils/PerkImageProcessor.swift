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

@MainActor
class PerkImageProcessor {
    private let context = CIContext()

    /// Preprocess image: remove background color and normalize for CoreML input
    func preprocess(_ image: UIImage, targetSize: CGSize = CGSize(width: 128, height: 128)) -> CVPixelBuffer? {
        guard var ciImage = CIImage(image: image) else { return nil }

        // --- Step 1: Reduce colorful background influence ---
        ciImage = removeColorfulBackground(ciImage)

        // --- Step 2: Convert to grayscale for consistency ---
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = 0.0
        colorControls.contrast = 1.4
        colorControls.brightness = 0.05
        guard let grayImage = colorControls.outputImage else { return nil }
        ciImage = grayImage

        // --- Step 3: Resize to model input size ---
        let scaleX = targetSize.width / ciImage.extent.width
        let scaleY = targetSize.height / ciImage.extent.height
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // --- Step 4: Convert to CVPixelBuffer for CoreML ---
        return pixelBuffer(from: resized, context: context, size: targetSize)
    }

    /// Removes strong color backgrounds (purple, green, blue, yellow, etc.)
    private func removeColorfulBackground(_ image: CIImage) -> CIImage {
        // Desaturate highly saturated pixels — simulating color masking
        let saturationReduction = CIFilter.colorMatrix()
        saturationReduction.inputImage = image

        // We suppress high R/G/B values slightly and bias toward neutral gray
        saturationReduction.rVector = CIVector(x: 0.5, y: -0.1, z: -0.1, w: 0)
        saturationReduction.gVector = CIVector(x: -0.1, y: 0.5, z: -0.1, w: 0)
        saturationReduction.bVector = CIVector(x: -0.1, y: -0.1, z: 0.5, w: 0)
        saturationReduction.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)

        guard var output = saturationReduction.outputImage else { return image }

        // Apply a small blur to smooth color transitions
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = output
        blur.radius = 1.0
        if let blurred = blur.outputImage {
            output = blurred
        }

        return output
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
