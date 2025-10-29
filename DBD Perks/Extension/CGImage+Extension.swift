//
//  CGImage+Extension.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import CoreGraphics
import CoreImage
import UIKit

extension CGImage {
    static func mock(color: UIColor = .gray,
                     size: CGSize = CGSize(width: 400, height: 600)) -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // optional: overlay text to see orientation
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let string = "Camera Preview"
            string.draw(with: CGRect(x: 0, y: size.height / 3,
                                     width: size.width, height: 100),
                        options: .usesLineFragmentOrigin,
                        attributes: attrs,
                        context: nil)
        }
        return uiImage.cgImage!
    }
}
