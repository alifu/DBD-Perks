//
//  String+Extension.swift
//  DBD Perks
//
//  Created by Alif on 30/10/25.
//

import Foundation

extension String {
    
    func remove(character: String) -> String {
        return self.replacingOccurrences(of: character, with: "")
    }
    
    func insertSpacesBeforeCapitals() -> String {
        let pattern = #"(?<!^)(?=[A-Z])"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(startIndex..., in: self)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: " ")
    }
    
    func extractPerkName() -> String {
        let data = self.remove(character: "File:IconPerks_").remove(character: ".png")
        return data.insertSpacesBeforeCapitals().capitalized
    }
}
