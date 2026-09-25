//
//  Styles.swift
//  GOTronome
//
//  Drum styles read from styles.txt, a file kept byte-identical with the
//  Android app. Pure values and functions; nothing here touches the engine.
//

import Foundation

let styleMetronome = "metronome"
let stylesResourceName = "styles"
let maxStepsPerBeat = 4

/// One measure of a drum style: `stepsPerBeat` sub-steps per beat, each a voice bitmask.
struct Groove: Equatable {
    let stepsPerBeat: Int
    let stepVoices: [Int32]
}

/// Grooves keyed by time signature. The metronome style has none and is valid everywhere.
struct Style: Equatable, Identifiable {
    let id: String
    let name: String
    let grooves: [String: Groove]

    var isMetronome: Bool { id == styleMetronome }

    func supports(_ timeSignature: String) -> Bool {
        isMetronome || grooves[timeSignature] != nil
    }
}

let metronomeStyle = Style(id: styleMetronome, name: "Metronome", grooves: [:])

func stylesFor(_ styles: [Style], timeSignature: String) -> [Style] {
    styles.filter { $0.supports(timeSignature) }
}

/// The style to actually play: the saved one when it has a groove for the time
/// signature, otherwise the metronome. The saved preference itself is left untouched.
func resolveStyle(_ styles: [Style], savedId: String, timeSignature: String) -> Style {
    styles.first { $0.id == savedId && $0.supports(timeSignature) }
        ?? styles.first { $0.isMetronome }
        ?? metronomeStyle
}

struct StylesParseError: Error, CustomStringConvertible {
    let line: Int
    let message: String
    var description: String { "\(stylesResourceName).txt:\(line) \(message)" }
}

private let voiceLetters: [Character: Int32] = [
    "K": Int32(VOICE_KICK.rawValue),
    "S": Int32(VOICE_SNARE.rawValue),
    "H": Int32(VOICE_HAT_CLOSED.rawValue),
    "P": Int32(VOICE_HAT_PEDAL.rawValue),
    "R": Int32(VOICE_RIDE.rawValue),
    "X": Int32(VOICE_CROSS_STICK.rawValue),
]

private func parseStep(_ token: Substring, line: Int) throws -> Int32 {
    if token == "." { return 0 }
    return try token.reduce(Int32(0)) { mask, letter in
        guard let voice = voiceLetters[letter] else {
            throw StylesParseError(line: line, message: "unknown voice '\(letter)'")
        }
        return mask | voice
    }
}

private func parseGroove(_ fields: [Substring], line: Int) throws -> (String, Groove) {
    guard fields.count >= 3 else {
        throw StylesParseError(line: line, message: "groove needs <time signature> <steps per beat> <steps>")
    }
    let timeSignature = String(fields[0])
    guard timeSignatures.contains(timeSignature) else {
        throw StylesParseError(line: line, message: "unknown time signature '\(timeSignature)'")
    }
    guard let stepsPerBeat = Int(fields[1]), (1...maxStepsPerBeat).contains(stepsPerBeat) else {
        throw StylesParseError(line: line, message: "steps per beat must be 1...\(maxStepsPerBeat)")
    }
    let tokens = fields.dropFirst(2)
    let expected = AccentPattern.beats(for: timeSignature) * stepsPerBeat
    guard tokens.count == expected else {
        throw StylesParseError(line: line, message: "expected \(expected) steps, got \(tokens.count)")
    }
    let voices = try tokens.map { try parseStep($0, line: line) }
    return (timeSignature, Groove(stepsPerBeat: stepsPerBeat, stepVoices: voices))
}

/// Parses the shared styles file. Throws a `StylesParseError` naming the offending line.
func parseStyles(_ text: String) throws -> [Style] {
    var styles: [Style] = []
    for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        let line = index + 1
        let content = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        let fields = content.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" })
        guard let directive = fields.first else { continue }
        switch directive {
        case "style":
            guard fields.count >= 3 else { throw StylesParseError(line: line, message: "style needs <id> <name>") }
            let name = fields.dropFirst(2).joined(separator: " ")
            styles.append(Style(id: String(fields[1]), name: name, grooves: [:]))
        case "groove":
            guard let current = styles.last else {
                throw StylesParseError(line: line, message: "groove before any style")
            }
            guard !current.isMetronome else {
                throw StylesParseError(line: line, message: "the metronome style takes no grooves")
            }
            let (timeSignature, groove) = try parseGroove(Array(fields.dropFirst()), line: line)
            var grooves = current.grooves
            grooves[timeSignature] = groove
            styles[styles.count - 1] = Style(id: current.id, name: current.name, grooves: grooves)
        default:
            throw StylesParseError(line: line, message: "unknown directive '\(directive)'")
        }
    }
    guard styles.contains(where: { $0.isMetronome }) else {
        throw StylesParseError(line: 0, message: "no metronome style")
    }
    return styles
}

/// The bundled styles; falls back to the metronome alone if the file is missing or malformed.
func loadBundledStyles() -> [Style] {
    guard let url = Bundle.main.url(forResource: stylesResourceName, withExtension: "txt"),
          let text = try? String(contentsOf: url, encoding: .utf8) else {
        print("Styles: \(stylesResourceName).txt missing from the bundle")
        return [metronomeStyle]
    }
    do {
        return try parseStyles(text)
    } catch {
        print("Styles: \(error)")
        return [metronomeStyle]
    }
}
