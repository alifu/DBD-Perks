//
//  CIImage+Extension.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import CoreImage

extension CIImage {
    
    var cgImage: CGImage? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else {
            return nil
        }
        return cgImage
    }
}
