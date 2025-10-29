//
//  PredictionView.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import SwiftUI

struct PredictionView: View {
    
    var capturedImage: UIImage?
    
    var body: some View {
        if let capturedImage {
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFit()
        } else {
            Text("No Image Captured")
        }
    }
}
