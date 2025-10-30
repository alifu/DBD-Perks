//
//  PredictionImageListView.swift
//  DBD Perks
//
//  Created by Alif on 30/10/25.
//

import SwiftUI
import NukeUI

struct PredictionImageListView: View {
    let imageURLs: [URL]
    let perkNames: [String]
    @State private var selectedPerkName: String = "-"
    @State private var perkDescription: String = "-"
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(zip(perkNames, imageURLs)), id: \.1) { perkName, url in
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedPerkName == perkName
                                                ? Color.blue.opacity(0.8)
                                                : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                                    .shadow(radius: 3)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedPerkName = perkName
                                        }
                                        self.fetcthPerksDescription(of: perkName)
                                    }
                            } else if state.error != nil {
                                Color.red
                                    .frame(width: 80, height: 80)
                                    .overlay(Text("❌").font(.largeTitle))
                            } else {
                                ProgressView()
                                    .frame(width: 80, height: 80)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            Text("Perk name: \($selectedPerkName.wrappedValue.extractPerkName())")
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            Divider()
            
            Text(perkDescription)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }
    
    private func fetcthPerksDescription(of name: String) {
        if let model = try? DBDPerkClassifier_Tuned(configuration: .init()) {
            if let jsonString = model.model.modelDescription.metadata[.creatorDefinedKey] as? [String: String],
               let perkJSON = jsonString["labels_json"] {
                if let data = perkJSON.data(using: .utf8),
                   let perks = try? JSONDecoder().decode([String: Perk].self, from: data) {
                    perkDescription = perks[name]?.description ?? ""
                }
            }
        }
    }
}
