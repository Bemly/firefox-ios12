//
//  BackgroundAudioManager.swift
//  Reynard
//
//  Created by Minh Ton on 26/7/26.
//

// https://github.com/StephenDev0/StikDebug/blob/03b7c109ac2767d7558e88c621924fbf9b18ad74/StikDebug/Services/BackgroundAudioManager.swift

import AVFoundation

final class BackgroundAudioManager {
    static let shared = BackgroundAudioManager()
    
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private var healthCheckTimer: Timer?
    private var isRunning = false
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func start() {
        guard !isRunning else {
            recoverIfNeeded()
            return
        }
        
        isRunning = true
        startEngine()
        startHealthCheck()
    }
    
    func stop() {
        guard isRunning else {
            return
        }
        
        isRunning = false
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
    
    private func startEngine() {
        do {
            engine.stop()
            player.stop()
            engine = AVAudioEngine()
            player = AVAudioPlayerNode()
            
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
            
            engine.attach(player)
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            scheduleSilence()
            try engine.start()
            player.play()
        } catch {
            NSLog("BackgroundAudioManager: %@", error.localizedDescription)
        }
    }
    
    private func scheduleSilence() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let frameCount = AVAudioFrameCount(format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            return
        }
        
        buffer.frameLength = frameCount
        player.scheduleBuffer(buffer, at: nil, options: .loops)
    }
    
    private func startHealthCheck() {
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.recoverIfNeeded()
        }
        RunLoop.main.add(timer, forMode: .common)
        healthCheckTimer = timer
    }
    
    private func recoverIfNeeded() {
        guard isRunning,
              !engine.isRunning || !player.isPlaying else {
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning {
                try engine.start()
            }
            player.play()
        } catch {
            return
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard isRunning,
              let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: typeValue) == .ended else {
            return
        }
        
        recoverIfNeeded()
    }
    
    @objc private func handleMediaServicesReset() {
        guard isRunning else {
            return
        }
        
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        startEngine()
    }
}
