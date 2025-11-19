//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation
import AVFoundation
import Speech
import Combine

final class SpeechHandler: NSObject, ObservableObject {
    // Public state for SwiftUI
    @Published private(set) var isRecording = false
    @Published var transcript: String = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var lastError: Error?
    
    // Configuration
    var locale: Locale = Locale(identifier: "en-US")
    var silenceTimeout: TimeInterval = 2.5
    
    // Internals
    private var speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastSpeechTime: Date = .distantPast
    private var availabilityCancellable: AnyCancellable?
    private var monitorTask: Task<Void, Never>?
    
    // MARK: - Authorization
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
        }
    }
    
    // MARK: - Recording Control
    func start() {
        guard !isRecording else { return }
        lastError = nil
        
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            lastError = SpeechHandlerError.recognizerUnavailable
            return
        }
        
        do {
            try configureAudioSession()
            try startAudioEngine()
            try startRecognition(using: recognizer)
            startSilenceMonitor()
            
            DispatchQueue.main.async { self.isRecording = true }
        } catch {
            stop() // best-effort cleanup
            lastError = error
        }
    }
    
    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionTask = nil
        recognitionRequest = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    // MARK: - Private helpers
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Handle interruptions
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard
                let userInfo = note.userInfo,
                let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }
            
            if type == .began {
                self.stop()
            }
        }
    }
    
    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func startRecognition(using recognizer: SFSpeechRecognizer) throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        transcript = ""
        lastSpeechTime = Date()
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                self.lastSpeechTime = Date()
            }
            if let error = error {
                self.lastError = error
            }
        }
    }
    
    private func startSilenceMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isRecording {
                let elapsed = Date().timeIntervalSince(self.lastSpeechTime)
                if elapsed >= self.silenceTimeout {
                    await MainActor.run { self.stop() }
                    break
                }
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            }
        }
    }
}

// MARK: - Errors
enum SpeechHandlerError: LocalizedError {
    case recognizerUnavailable
    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return L10n.Transcription.recognizerUnavailable
        }
    }
}
