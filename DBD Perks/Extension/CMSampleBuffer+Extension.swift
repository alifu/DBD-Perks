//
//  CMSampleBuffer+Extension.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import AVFoundation
import CoreImage

extension CMSampleBuffer {
    
    var cgImage: CGImage? {
        let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(self)
        guard let imagePixelBuffer = pixelBuffer else {
            return nil
        }
        return CIImage(cvPixelBuffer: imagePixelBuffer).cgImage
    }
}
