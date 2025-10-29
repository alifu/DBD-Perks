//
//  CameraView.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import SwiftUI

struct CameraView: View {
    
    @Binding var image: CGImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                } else {
                    ContentUnavailableView("No camera feed", systemImage: "xmark.circle.fill")
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                }
                
                // Overlay crop box (128×128 center)
                let overlaySize: CGFloat = 128
                Rectangle()
                    .strokeBorder(Color.yellow, lineWidth: 2)
                    .frame(width: overlaySize, height: overlaySize)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                
                // Dimmed outside area
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .fill(style: FillStyle(eoFill: true))
                            .overlay(
                                Rectangle()
                                    .frame(width: overlaySize, height: overlaySize)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    let sampleImage = CGImage.mock()
    return CameraView(image: .constant(sampleImage))
}
