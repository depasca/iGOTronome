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

enum MetronomeMode : String, CaseIterable, Identifiable, CustomStringConvertible {
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
    @Published private(set) var isSilentBar: Bool = false
    @Published private(set) var beatPhase: Float = 0.0
    @Published private(set) var beatsPerMinute: Int = 120
    @Published private(set) var beatsPerMeasure: Int = 4
    @Published private(set) var timeSignature: String = "4/4"
    @Published private(set) var numBars: Int = 0
    @Published private(set) var numSilentBars: Int = 0
    @Published private(set) var mode: MetronomeMode = .basic
    @Published private(set) var silentBarsEnabled: Bool = false
    @Published private(set) var isCountingIn: Bool = false
    
    private var displayLink: CADisplayLink?
    private var isRunning = false

    init() {
        loadBundledSamples()
        registerAudioObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start(ts: String, bpm: Int, ns: Int, nb: Int, countIn: Bool) {
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
        let pattern = AccentPattern.load(for: ts).map(Int32.init)
        metronome_set_accent_pattern(pattern, Int32(pattern.count))
        metronome_start(UInt32(bpm), UInt32(beatsPerMeasure), UInt32(numSilentBars), UInt32(numBars), silentBarsEnabled, countIn)
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
        let silent = metronome_get_is_silent_bar()
        let counting = metronome_get_is_counting_in()
        // Update only on changes to minimize UI churn
        if beat != currentBeat || abs(phase - beatPhase) > 0.001 || counting != isCountingIn {
            currentBeat = beat
            beatPhase = phase
            currentBar = bar
            isSilentBar = silent
            isCountingIn = counting
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

    // Recover playback when the output route changes (Bluetooth/headphones
    // connect or disconnect) or the media server resets, rebuilding the audio
    // unit on the new route so the click continues in place.
    private func registerAudioObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleMediaReset(_:)),
                       name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: nil)
    }

    @objc private func handleRouteChange(_ note: Notification) {
        guard isRunning,
              let value = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: value) else { return }
        switch reason {
        case .oldDeviceUnavailable, .newDeviceAvailable, .override, .routeConfigurationChange:
            metronome_restart_audio()
        default:
            break
        }
    }

    @objc private func handleMediaReset(_ note: Notification) {
        guard isRunning else { return }
        configureAudioSession()
        metronome_restart_audio()
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard isRunning,
              let value = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: value),
              type == .ended else { return }
        configureAudioSession()
        metronome_restart_audio()
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
