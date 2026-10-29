//
//  TopK.swift
//  DBD Perks
//

enum TopK {
    /// Highest `k` scores in descending order without sorting everything:
    /// O(N log k) comparisons and O(k) space (the full sort it replaces is O(N log N)).
    static func select(
        from scores: [String: Double],
        k: Int,
        where isIncluded: (String) -> Bool = { _ in true }
    ) -> [(label: String, score: Double)] {
        guard k > 0 else { return [] }
        var best: [(label: String, score: Double)] = []
        best.reserveCapacity(k + 1)

        for (label, score) in scores where isIncluded(label) {
            if best.count == k, let worst = best.last, score <= worst.score { continue }

            var low = 0
            var high = best.count
            while low < high {
                let middle = (low + high) / 2
                if best[middle].score >= score { low = middle + 1 } else { high = middle }
            }
            best.insert((label, score), at: low)
            if best.count > k { best.removeLast() }
        }
        return best
    }
}
