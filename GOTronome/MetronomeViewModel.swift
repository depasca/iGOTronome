//
//  MetronomeViewModel.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 30.09.25.
//

import Foundation
import Combine
import UIKit
import AVFoundation

enum MetronomeMode : CaseIterable, Identifiable, CustomStringConvertible {
    case basic
    case barLoop
    case silenBars
    var id: Self { self }
    var description: String {
        switch self {
        case .basic:
            return "Basic"
        case .barLoop:
            return "Bar Loop"
        case .silenBars:
            return "Silent Bars"
        }
    }
}

final class MetronomeViewModel: ObservableObject {
    @Published private(set) var currentBeat: Int = 0
    @Published private(set) var currentBar: Int = 0
    @Published private(set) var beatPhase: Float = 0.0
    @Published private(set) var beatsPerMinute: Int = 120
    @Published private(set) var beatsPerMeasure: Int = 4
    @Published private(set) var timeSignature: String = "4/4"
    @Published private(set) var numBars: Int = 0
    @Published private(set) var numSilentBars: Int = 0
    @Published private(set) var mode: MetronomeMode = .basic
    @Published private(set) var silentBarsEnabled: Bool = false
    
    private var displayLink: CADisplayLink?
    private var isRunning = false

    func start(ts: String, bpm: Int, ns: Int, nb: Int) {
        // ensure audio session configured before start
        configureAudioSession()
        startDisplayLink()
        isRunning = true
        beatsPerMinute = bpm
        timeSignature = ts
        numBars = nb
        numSilentBars = ns
        switch(ts) {
            case "4/4":
                beatsPerMeasure = 4
            case "3/4":
                beatsPerMeasure = 3
            case "2/4":
                beatsPerMeasure = 2
            case "2/2":
                beatsPerMeasure = 2
            case "6/8":
                beatsPerMeasure = 6
            default:
                beatsPerMeasure = 4
        }
//        metronome_start(UInt32(bpm), UInt32(beatsPerMeasure), UInt32(numSilentBars), UInt32(numBars), silentBarsEnabled)
        metronome_start(UInt32(bpm), UInt32(beatsPerMeasure), UInt32(0), UInt32(numBars), false)
    }

    func stop() {
        metronome_stop()
        stopDisplayLink()
        isRunning = false
        DispatchQueue.main.async {
            self.currentBeat = 0
            self.beatPhase = 0.0
        }
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func handleDisplayLink() {
        // Poll native C engine
        let beat = Int(metronome_get_current_beat())
        let phase = Float(metronome_get_current_beat_phase())
        let bar = Int(metronome_get_current_bar())
        // Update only on changes to minimize UI churn
        if beat != currentBeat || abs(phase - beatPhase) > 0.001 {
            currentBeat = beat
            beatPhase = phase
            currentBar = bar
        }
    }

    // simple audio session helper; can be moved out
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession error: \(error)")
        }
    }
    
    public func setMode(m: MetronomeMode) {
        mode = m
        silentBarsEnabled = mode == .silenBars
        print("silentBarEnabled: \(mode) \(silentBarsEnabled)")
    }
    public func setSilentBarsEnabled(sb: Bool) {
        silentBarsEnabled = sb
    }
}
