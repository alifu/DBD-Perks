//
//  PredictionViewModel.swift
//  DBD Perks
//
//  Created by Alif on 30/10/25.
//

import Foundation
import SwiftUI
import CoreML

struct Perk: Decodable {
    let name: String
    let description: String
}

@Observable
class PredictionViewModel {
    
    private let service = DBDPerkImageService()
    var resultPerks: [String] = []
    var previewImage: UIImage?
    var predictionLog: String = ""
    var resultPerksImageURL: [URL] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    @MainActor
    func runPreprocess(capturedImage: UIImage?, processor: PerkImageProcessor) {
        
        guard let sample = capturedImage else { return }
        if let buffer = processor.preprocess(sample) {
            let model = try? DBDPerkClassifier_Tuned(configuration: MLModelConfiguration())
            
            if let result = try? model?.prediction(input_1: buffer) {
                predictionLog = "🎯 Predicted: \(result.classLabel)\n"
                
                let sorted = result.classLabel_probs.sorted { $0.value > $1.value }
                
                for (i, (label, prob)) in sorted.prefix(10).enumerated() {
                    predictionLog += "  \(i+1). \(label): \(String(format: "%.2f", prob * 100))%\n"
                    resultPerks.append(label)
                }
            } else {
                predictionLog = "❌ Prediction failed."
            }
            
            let ciImage = CIImage(cvPixelBuffer: buffer)
            let context = CIContext()
            
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                previewImage = uiImage
            } else {
                print("⚠️ Failed to create CGImage from CIImage")
            }
        }
    }
    
    func loadImage() {
        if !resultPerksImageURL.isEmpty { return }
        Task {
            isLoading = true
            let urls = await service.fetchPerkImageURLs(resultPerks)
            self.resultPerksImageURL = urls
            isLoading = false
            print("🎨 Got \(urls.count) URLs")
        }
    }
}
