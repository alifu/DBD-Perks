//
//  GameIconStore.swift
//  DBD Perks
//

import UIKit

/// Perk and add-on icons exported from the game and bundled as small PNGs.
/// The files are git-ignored (copyrighted), so a fresh clone has none and callers fall back to a placeholder or the wiki image.
enum GameIconStore {
    private static let cache = NSCache<NSString, UIImage>()

    /// `name` is the file name without extension, lower-case.
    static func image(named name: String, bundle: Bundle = .main) -> UIImage? {
        let key = name.lowercased() as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let path = bundle.path(forResource: key as String, ofType: "png"),
              let image = UIImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

enum AddonIconStore {
    static func image(forIconStem stem: String, bundle: Bundle = .main) -> UIImage? {
        GameIconStore.image(named: stem, bundle: bundle)
    }
}

enum PerkIconStore {
    static func image(forPerkID id: String, bundle: Bundle = .main) -> UIImage? {
        GameIconStore.image(named: "perk_\(id)", bundle: bundle)
    }
}
