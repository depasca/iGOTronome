//
//  AccentPattern.swift
//  GOTronome
//
//  Per-beat accent pattern: 2 = accent, 1 = normal, 0 = mute. Stored per time
//  signature so each meter keeps its own feel.
//

import Foundation

let timeSignatures = ["4/4", "3/4", "2/4", "2/2", "6/8"]

enum BeatLevel {
    static let mute = 0
    static let normal = 1
    static let accent = 2
}

enum AccentPattern {
    static func beats(for timeSignature: String) -> Int {
        switch timeSignature {
        case "4/4": return 4
        case "3/4": return 3
        case "2/4": return 2
        case "2/2": return 2
        case "6/8": return 6
        default: return 4
        }
    }

    static func defaultPattern(for timeSignature: String) -> [Int] {
        let count = beats(for: timeSignature)
        return (0..<count).map { $0 == 0 ? BeatLevel.accent : BeatLevel.normal }
    }

    private static func key(for timeSignature: String) -> String {
        "accent_pattern_\(timeSignature)"
    }

    static func load(for timeSignature: String) -> [Int] {
        let stored = UserDefaults.standard.string(forKey: key(for: timeSignature))
        let parsed = stored?.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if let parsed, parsed.count == beats(for: timeSignature) {
            return parsed
        }
        return defaultPattern(for: timeSignature)
    }

    static func save(_ pattern: [Int], for timeSignature: String) {
        let joined = pattern.map(String.init).joined(separator: ",")
        UserDefaults.standard.set(joined, forKey: key(for: timeSignature))
    }

    // Cycle a single beat: accent -> normal -> mute -> accent.
    static func cycled(_ pattern: [Int], at index: Int) -> [Int] {
        guard pattern.indices.contains(index) else { return pattern }
        var updated = pattern
        updated[index] = (updated[index] + 2) % 3
        return updated
    }
}
