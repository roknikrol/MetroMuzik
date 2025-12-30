//
//  MetronomeEngine.swift
//  MetroMuzik
//
//  Created by Nikita Podobedov on 12/3/25.
//

import Foundation
import AVFoundation

#if os(watchOS)
import WatchKit
#endif

class MetronomeEngineiOS: NSObject, ObservableObject {
    @Published var bpm: Double = 120.0 {
        didSet {
            // Optional: clamp here too if you don’t already
                   if bpm < 40 { bpm = 40 }
                   if bpm > 400 { bpm = 400 }

                   // If metronome is running, update its speed
                   if isPlaying {
                       startTimer()
                   }
        }
    }
    @Published var hapticsOnly: Bool = false
    @Published var isPlaying: Bool = false
    @Published var timeSignature: Int = 4
    @Published var subdivision: Int = 1 // 1 = quarter, 2 = eighth

#if os(watchOS)
    /// Keeps the watch app running (time-limited) when the display dims / wrist goes down.
    /// Without this, timers and UI callbacks may pause in Always On / inactive state.
    private var extendedRuntimeSession: WKExtendedRuntimeSession?
#endif

    private var currentBeat: Int = 0
    private var subTickCount: Int = 0
    private var timer: Timer?
    private var accentPlayer: AVAudioPlayer?
    private var subPlayer: AVAudioPlayer?
    private var isReschedulingTimer: Bool = false
    
    #if os(watchOS)
    private func startExtendedRuntimeIfNeeded() {
        // If already running, do nothing
        if let s = extendedRuntimeSession, s.state == .running { return }

        let s = WKExtendedRuntimeSession()
        s.delegate = self
        extendedRuntimeSession = s
        s.start()
    }

    private func stopExtendedRuntimeIfNeeded() {
        extendedRuntimeSession?.invalidate()
        extendedRuntimeSession = nil
    }
    #endif

    override init(){
        super.init()
        setupAudioPLayer()
        #if os(iOS) || os(watchOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }
    
    private func setupAudioPLayer() {
        func loadPlayer(fileName: String) -> AVAudioPlayer? {
            guard let soundURL = Bundle.main.url(forResource: fileName, withExtension: "wav") else {
                print("Sound file not found: \(fileName).wav")
                return nil
            }
            
            do {
                let player = try AVAudioPlayer(contentsOf: soundURL)
                player.prepareToPlay()
                return player
            } catch {
                print("Error loading sound file: \(error)")
                return nil
            }
        }
        //initialize both player
        accentPlayer = loadPlayer(fileName: "boop")
        subPlayer = loadPlayer(fileName: "bip")
    }
    
    // MARK: - update bpm from knob
    // For Tap Tempo logic
    private var tapTimes: [Date] = []
    
    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            startTimer()
            #if os(watchOS)
            startExtendedRuntimeIfNeeded()
            #endif
        } else {
            stopTimer()
            #if os(watchOS)
            stopExtendedRuntimeIfNeeded()
            #endif
        }
    }
    
    private func startTimer() {
        stopTimer()
        // Calculate interval: 60 seconds / BPM / subdivision
        let interval = 60.0 / bpm
        
        // Schedule the timer
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.advanceBeatAndPLayTick()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func advanceBeatAndPLayTick() {
        // 1. Advance the sub-tick counter
        currentBeat += 1

        // 2. Check if we've started a new measure (Beat 1)
        if currentBeat > timeSignature {
            currentBeat = 1 // Reset to the first beat of the next measure
        }

        // Play Accent sound only on the first subdivision tick (subTickCount == 0)
        // AND only if it's the first beat of the measure (currentBeat == 1)
        if currentBeat == 1 {
            playAccentTick()
        } else {
            playSubTick()
        }
    }
    
    // In MetronomeEngine.swift

    private func playAccentTick() {
        // On all platforms, optionally play the accent sound
        if !hapticsOnly {
            accentPlayer?.stop()
            accentPlayer?.currentTime = 0
            accentPlayer?.play()
        }
        #if os(watchOS)
        WKInterfaceDevice.current().play(.failure)
        #endif
    }

    private func playSubTick() {
        // On all platforms, optionally play the subdivision sound
        if !hapticsOnly {
            subPlayer?.stop()
            subPlayer?.currentTime = 0
            subPlayer?.play()
        }
        #if os(watchOS)
        WKInterfaceDevice.current().play(.retry)
        #endif
    }
    
    // MARK: - update bpm from knob
    // Updates BPM based on the 3D wheel rotation
    func updateBpmFromKnob(angle: Double) {
        // angle is in degrees, 0° at noon, increasing clockwise
        // Each 25° → 5 BPM, starting at 120 BPM when angle = 0°
        var newBpm = 120.0 + (angle / 25.0) * 5.0
        // Optional clamp to keep in a sane range
        newBpm = max(40, min(400, newBpm))
        bpm = newBpm
    }
    
    
    // MARK: - Tap tempo
    ///
    func tapTempo() {
        let now = Date()
        
        // Reset if taps are too far apart (start over)
        if let lastTap = tapTimes.last, now.timeIntervalSince(lastTap) > 2.0 {
            tapTimes.removeAll()
        }
        
        tapTimes.append(now)
        
        // We need at least 2 taps to calculate intervals
        if tapTimes.count > 1 {
            // Keep only last 5 taps for average
            if tapTimes.count > 5 { tapTimes.removeFirst() }
            
            var intervals: [TimeInterval] = []
            for i in 1..<tapTimes.count {
                intervals.append(tapTimes[i].timeIntervalSince(tapTimes[i-1]))
            }
            
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            let newBpm = 60.0 / avgInterval
            self.bpm = round(newBpm)
        }
    }
}

// below extension is required to keep the app running when the wrist is turned (screen dimed)
#if os(watchOS)
extension MetronomeEngineiOS: WKExtendedRuntimeSessionDelegate {
   
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Session started. Good time to ensure audio session stays active if needed.
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // The system will end the session soon. Stop cleanly.
        DispatchQueue.main.async {
            if self.isPlaying {
                self.isPlaying = false
            }
            self.stopTimer()
        }
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                               didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                               error: Error?) {
        // Session ended (time limit, user action, system decision, etc.).
        // IMPORTANT: don’t automatically stop the metronome here.
        // The app can still be in the foreground and should keep playing.
        DispatchQueue.main.async {
            self.extendedRuntimeSession = nil
        }
    }
}
#endif

