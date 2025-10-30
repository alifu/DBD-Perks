//
//  DBDPerkImageService.swift
//  DBD Perks
//
//  Created by Alif on 30/10/25.
//

import Foundation
import Moya

// MARK: - API Target

struct CustomLoggerPlugin: PluginType {
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        print("Custom Logger - Preparing Request: \(request.url?.absoluteString ?? "N/A")")
        return request
    }
    
    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        switch result {
        case .success(let response):
            print("Custom Logger - Received Success Response for: \(target.path)")
            print("Response Data: \(String(data: response.data, encoding: .utf8) ?? "N/A")")
        case .failure(let error):
            print("Custom Logger - Received Failure Response for: \(target.path)")
            print("Error: \(error.localizedDescription)")
        }
    }
}

enum DBDPerkAPI {
    case imageInfo(perkFileName: String)
}

extension DBDPerkAPI: TargetType {
    var baseURL: URL { URL(string: "https://deadbydaylight.fandom.com/api.php")! }
    var path: String { "" } // all params via query
    var method: Moya.Method { .get }
    
    var task: Task {
        switch self {
        case .imageInfo(let perkFileName):
            return .requestParameters(
                parameters: [
                    "action": "query",
                    "format": "json",
                    "titles": perkFileName,
                    "prop": "imageinfo",
                    "iiprop": "url"
                ],
                encoding: URLEncoding.default
            )
        }
    }
    
    var headers: [String : String]? {
        ["User-Agent": "DBDPerkFetcher/1.0 (Swift+iOS)"]
    }
    
    var sampleData: Data { Data() }
}

// MARK: - Service

final class DBDPerkImageService {
    private let provider = MoyaProvider<DBDPerkAPI>(plugins: [CustomLoggerPlugin()])
    
    /// Fetch image URLs for perk items
    func fetchPerkImageURLs(_ perkItems: [String]) async -> [URL] {
        var urls: [URL] = []
        
        for (index, perk) in perkItems.enumerated() {
            do {
                if let url = try await fetchPerkImageURL(perkFileName: "\(perk).png") {
                    urls.append(url)
                    print("[\(index + 1)/\(perkItems.count)] ✅ \(perk)")
                } else {
                    print("[\(index + 1)/\(perkItems.count)] ⚠️ No image for \(perk)")
                }
            } catch {
                print("[\(index + 1)/\(perkItems.count)] ❌ Failed \(perk): \(error.localizedDescription)")
            }
            
            // small delay to respect rate limits
            await asyncDelay(seconds: 0.2)
        }
        
        return urls
    }
    
    /// Fetch a single perk image URL
    private func fetchPerkImageURL(perkFileName: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.request(.imageInfo(perkFileName: perkFileName)) { result in
                switch result {
                case .success(let response):
                    do {
                        let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
                        if let query = json?["query"] as? [String: Any],
                           let pages = query["pages"] as? [String: Any] {
                            for (_, page) in pages {
                                if let page = page as? [String: Any],
                                   let imageinfo = page["imageinfo"] as? [[String: Any]],
                                   let urlString = imageinfo.first?["url"] as? String,
                                   let url = URL(string: urlString) {
                                    continuation.resume(returning: url)
                                    return
                                }
                            }
                        }
                        continuation.resume(returning: nil)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Cross-version async delay
    private func asyncDelay(seconds: Double) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                continuation.resume()
            }
        }
    }
}
