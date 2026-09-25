//
//  SampleLoader.swift
//  GOTronome
//
//  Loads the recorded one-shots bundled under Samples/ into the C engine at
//  launch. A voice without a file keeps its synthesized sound. Sources and
//  terms of the files are listed in SAMPLES.md at the repository root.
//

import AVFoundation

/// Recorded hits are scaled to this peak so they sit with the synth voices instead of over them.
let samplePeak: Float = 0.6

/// Bundled sample file name (without extension), engine voice flag and, for pitched
/// voices, the MIDI note the recording was made at (0 for drums).
let sampleFiles: [(name: String, voice: Int32, baseMidiNote: Int32)] = [
    ("ride", Int32(VOICE_RIDE.rawValue), 0),
    ("bass", Int32(VOICE_BASS.rawValue), 33),
]

/// Bit position of a single voice flag, e.g. voiceIndex(of: RIDE) == 6.
func voiceIndex(of voiceBit: Int32) -> Int32 { Int32(voiceBit.trailingZeroBitCount) }

/// Mixes a decoded buffer to mono in -1...1.
func monoFrames(_ buffer: AVAudioPCMBuffer) -> [Float] {
    guard let channels = buffer.floatChannelData else { return [] }
    let frames = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    return (0..<frames).map { frame in
        (0..<channelCount).reduce(Float(0)) { $0 + channels[$1][frame] } / Float(channelCount)
    }
}

func normalized(_ frames: [Float], peak: Float) -> [Float] {
    guard let current = frames.map({ abs($0) }).max(), current > 0 else { return frames }
    let gain = peak / current
    return frames.map { $0 * gain }
}

/// Decodes one bundled WAV with AVAudioFile. Returns nil when the file is missing or unreadable.
func decodeBundledSample(named name: String) -> (frames: [Float], rate: Int32)? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Samples") else { return nil }
    do {
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
        try file.read(into: buffer)
        return (monoFrames(buffer), Int32(file.processingFormat.sampleRate))
    } catch {
        print("SampleLoader: cannot read \(name).wav: \(error)")
        return nil
    }
}

/// Loads every bundled sample into the engine. Call before the metronome starts.
func loadBundledSamples() {
    for (name, voice, baseMidiNote) in sampleFiles {
        guard let clip = decodeBundledSample(named: name) else { continue }
        let frames = normalized(clip.frames, peak: samplePeak)
        let loaded = frames.withUnsafeBufferPointer { pointer in
            metronome_load_sample(voiceIndex(of: voice), pointer.baseAddress, Int32(frames.count), clip.rate, baseMidiNote)
        }
        print("SampleLoader: \(name).wav \(loaded ? "loaded" : "rejected"), \(frames.count) frames at \(clip.rate) Hz")
    }
}
