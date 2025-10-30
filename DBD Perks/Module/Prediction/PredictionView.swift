//
//  PredictionView.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import CoreML
import Vision
import SwiftUI

struct PredictionView: View {
    
    var capturedImage: UIImage?
    @State private var viewModel = PredictionViewModel()
    private let processor = PerkImageProcessor()
    @State private var isImageSectionEnabled = false
    
    var body: some View {
        if let capturedImage {
            ScrollView(.vertical) {
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .center) {
                            Text("Captured \nImage")
                                .font(.system(size: 12, design: .monospaced))
                                .multilineTextAlignment(.center)
                            
                            Image(uiImage: capturedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(alignment: .center) {
                            Text("Preprocessing \nImage")
                                .font(.system(size: 12, design: .monospaced))
                                .multilineTextAlignment(.center)
                            
                            if let uiImage = viewModel.previewImage {
                                VStack {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 150)
                                }
                            } else {
                                Text("No image yet")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    TextEditor(text: $viewModel.predictionLog)
                        .frame(height: 200)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(0)
                        .font(.system(size: 10, design: .monospaced))
                    
                    HStack {
                        Text("Show prediction Images:")
                            .font(.system(size: 12, design: .monospaced))
                        
                        Toggle("", isOn: $isImageSectionEnabled)
                            .foregroundStyle(.white)
                            .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onChange(of: isImageSectionEnabled) { _, newValue in
                        if newValue {
                            viewModel.loadImage()
                        }
                    }
                    
                    if isImageSectionEnabled {
                        if viewModel.isLoading {
                            ProgressView("Fetching Images…")
                                .font(.system(size: 10, design: .monospaced))
                                .padding()
                        } else if let error = viewModel.errorMessage {
                            Text("⚠️ \(error)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.red)
                                .padding()
                        } else if viewModel.resultPerksImageURL.isEmpty {
                            Text("No images found.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            PredictionImageListView(
                                imageURLs: viewModel.resultPerksImageURL,
                                perkNames: viewModel.resultPerks)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .onAppear() {
                viewModel.runPreprocess(
                    capturedImage: capturedImage,
                    processor: processor)
            }
        } else {
            Text("No Image Captured")
        }
    }
}

#Preview {
    PredictionView(capturedImage: UIImage(named: "hex-no-one-escapes-death"))
}
