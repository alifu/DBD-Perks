//
//  ScanRecorder.swift
//  DBD Perks
//

import UIKit

/// One slot of a scan as written to `scans.jsonl`.
struct ScannedSlotRecord: Codable, Equatable {
    let slot: Int
    let chosenPerkID: String?
    let topCandidates: [PerkCandidate]
}

struct ScanRecord: Codable, Equatable {
    let id: String
    let date: Date
    /// "guide" (crops lined up by the user) or "auto".
    let source: String
    let slots: [ScannedSlotRecord]
}

/// What the user said the perk really was, next to what the model said.
struct CorrectionRecord: Codable, Equatable {
    let scanID: String
    let slot: Int
    let correctPerkID: String
    let predictedPerkID: String?
    let topCandidates: [PerkCandidate]
}

/// Debug-only log of what the model saw, so wrong answers can be collected and the most confused perk pairs found.
///
/// Layout under `directory`:
/// - `scans.jsonl`                              one `ScanRecord` per line
/// - `crops/<scanID>_<slot>.jpg`                every crop the model scored
/// - `corrections/<perkID>/<scanID>_<slot>.jpg` crops the user marked wrong, filed under the right perk
///   (add-ons: `corrections/addons/<icon label>/...`)
/// - `corrections/<perkID>/<scanID>_<slot>.json` the matching `CorrectionRecord`
struct ScanRecorder {
    private static let jpegQuality: CGFloat = 0.9

    let directory: URL

    /// App's Documents folder, so the log can be copied off the phone.
    static func inDocuments() -> ScanRecorder? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            .map { ScanRecorder(directory: $0.appendingPathComponent("ScanLog", isDirectory: true)) }
    }

    /// Writes the crops and one log line. Returns the scan id, or nil if nothing could be written.
    @discardableResult
    func recordScan(source: String, crops: [UIImage], results: [SlotResult], date: Date = Date()) -> String? {
        let id = UUID().uuidString
        let record = ScanRecord(
            id: id, date: date, source: source,
            slots: results.map { ScannedSlotRecord(slot: $0.slot, chosenPerkID: $0.chosen?.perkID, topCandidates: $0.candidates) })
        do {
            let cropsDirectory = directory.appendingPathComponent("crops", isDirectory: true)
            try FileManager.default.createDirectory(at: cropsDirectory, withIntermediateDirectories: true)
            for (slot, crop) in crops.enumerated() {
                try write(crop, to: cropsDirectory.appendingPathComponent(Self.fileName(scanID: id, slot: slot, ext: "jpg")))
            }
            try append(line: try Self.encoder.encode(record), to: directory.appendingPathComponent("scans.jsonl"))
            return id
        } catch {
            return nil
        }
    }

    /// Files `crop` under the perk it really is (or, with `group` "addons", the add-on label). Returns false if it could not be written.
    @discardableResult
    func saveCorrection(_ correction: CorrectionRecord, crop: UIImage, group: String? = nil) -> Bool {
        var corrections = directory.appendingPathComponent("corrections", isDirectory: true)
        if let group { corrections.appendPathComponent(group, isDirectory: true) }
        let perkDirectory = corrections.appendingPathComponent(correction.correctPerkID, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: perkDirectory, withIntermediateDirectories: true)
            try write(crop, to: perkDirectory.appendingPathComponent(Self.fileName(scanID: correction.scanID, slot: correction.slot, ext: "jpg")))
            try Self.encoder.encode(correction)
                .write(to: perkDirectory.appendingPathComponent(Self.fileName(scanID: correction.scanID, slot: correction.slot, ext: "json")))
            return true
        } catch {
            return false
        }
    }

    private static func fileName(scanID: String, slot: Int, ext: String) -> String { "\(scanID)_\(slot).\(ext)" }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private func write(_ image: UIImage, to url: URL) throws {
        guard let data = image.jpegData(compressionQuality: Self.jpegQuality) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
    }

    private func append(line: Data, to url: URL) throws {
        let entry = line + Data("\n".utf8)
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: entry)
        } else {
            try entry.write(to: url)
        }
    }
}
