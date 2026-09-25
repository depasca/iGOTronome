//
//  StylesTests.swift
//  GOTronomeTests
//
//  Mirrors the Android StylesTest: the bundled file, the fallback rule and the parser.
//

import Testing
import Foundation
@testable import GOTronome

struct StylesTests {
    private func bundled() throws -> [Style] {
        let url = try #require(Bundle.main.url(forResource: "styles", withExtension: "txt"))
        return try parseStyles(try String(contentsOf: url, encoding: .utf8))
    }

    @Test func bundledFileDefinesEveryPlannedGroove() throws {
        let styles = try bundled()
        let expected: [String: Set<String>] = [
            "metronome": [], "rock": ["4/4", "6/8"], "swing": ["4/4"], "shuffle": ["4/4"],
            "waltz": ["3/4"], "bossa": ["4/4"], "samba": ["2/4", "4/4"], "march": ["2/4", "2/2"],
        ]
        #expect(Dictionary(uniqueKeysWithValues: styles.map { ($0.id, Set($0.grooves.keys)) }) == expected)
        for style in styles {
            for (timeSignature, groove) in style.grooves {
                #expect(groove.stepVoices.count == AccentPattern.beats(for: timeSignature) * groove.stepsPerBeat)
                let bass = try #require(groove.bass, "no bass line for \(style.id) \(timeSignature)")
                #expect(bass.notes.count == AccentPattern.beats(for: timeSignature) * bass.stepsPerBeat * bass.bars)
            }
        }
    }

    @Test func swingWalksTwoBarsAndBarSeparatorsAreIgnored() throws {
        let swing = try #require(bundled().first { $0.id == "swing" }?.grooves["4/4"]?.bass)
        #expect(swing.bars == 2)
        #expect(swing.stepsPerBeat == 1)
        #expect(swing.notes == [0, 4, 7, 9, 10, 9, 7, -1])
    }

    @Test func bassRestsAndRootRegister() throws {
        let styles = try parseStyles("""
            style metronome Metronome
            style test Test
            groove 2/4 2 K . S .
            bass 2/4 1 0 .
            """)
        #expect(styles.last?.grooves["2/4"]?.bass?.notes == [0, bassRest])
        #expect(bassRootMidi(4) == 28)   // E1
        #expect(bassRootMidi(0) == 36)   // C2
        #expect(bassRootMidi(3) == 39)   // E-flat 2, the top of the register
    }

    @Test func bassLineBeforeItsGrooveIsRejected() {
        do {
            _ = try parseStyles("style metronome Metronome\nstyle bad Bad\nbass 4/4 1 0 0 0 0")
            Issue.record("expected a parse error")
        } catch let error as StylesParseError {
            #expect(error.line == 3)
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func metronomeIsValidEverywhereAndListedFirst() throws {
        let styles = try bundled()
        for timeSignature in timeSignatures {
            #expect(stylesFor(styles, timeSignature: timeSignature).first?.id == "metronome")
        }
    }

    @Test func savedStyleWithoutGrooveFallsBackToMetronome() throws {
        let styles = try bundled()
        #expect(resolveStyle(styles, savedId: "swing", timeSignature: "4/4").id == "swing")
        #expect(resolveStyle(styles, savedId: "swing", timeSignature: "3/4").id == "metronome")
        #expect(resolveStyle(styles, savedId: "no-such-style", timeSignature: "4/4").id == "metronome")
    }

    @Test func stepTokensBecomeVoiceMasks() throws {
        let styles = try parseStyles("""
            style metronome Metronome
            style test Test # trailing comment
            groove 2/4 2 KH . S .
            """)
        let groove = try #require(styles.last?.grooves["2/4"])
        #expect(groove.stepsPerBeat == 2)
        #expect(groove.stepVoices == [Int32(VOICE_KICK.rawValue | VOICE_HAT_CLOSED.rawValue), 0, Int32(VOICE_SNARE.rawValue), 0])
    }

    @Test func wrongStepCountIsRejectedWithLineNumber() {
        #expect(throws: StylesParseError.self) {
            try parseStyles("style metronome Metronome\nstyle bad Bad\ngroove 4/4 2 K S")
        }
        do {
            _ = try parseStyles("style metronome Metronome\nstyle bad Bad\ngroove 4/4 2 K S")
        } catch let error as StylesParseError {
            #expect(error.line == 3)
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }
}
