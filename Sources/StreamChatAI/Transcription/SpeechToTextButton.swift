//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI

public struct SpeechToTextButton: View {
    @StateObject private var speech: SpeechHandler
    @State private var isRecording = false
    
    private var locale: Locale
    private var silenceTimeout: Double
    private let colors: Colors
    
    var onTranscriptChange: (String) -> ()
    
    public init(
        speechHandler: SpeechHandler? = nil,
        locale: Locale? = nil,
        silenceTimeout: Double = 2.0,
        colors: Colors = Colors(),
        onTranscriptChange: @escaping (String) -> () = { _ in }
    ) {
        self.locale = locale ?? Locale.current
        self.silenceTimeout = silenceTimeout
        self.colors = colors
        self.onTranscriptChange = onTranscriptChange
        _speech = StateObject(wrappedValue: speechHandler ?? .init())
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Button {
                if isRecording {
                    speech.stop()
                } else {
                    if speech.authorizationStatus == .notDetermined {
                        speech.requestAuthorization()
                    }
                    speech.start()
                }
            } label: {
                Image(systemName: isRecording ? "stop.circle" : "mic")
                    .foregroundStyle(colors.transcription.icon)
            }
        }
        .onAppear {
            speech.silenceTimeout = silenceTimeout
            speech.locale = locale
        }
        .onReceive(speech.$transcript) { newValue in
            onTranscriptChange(newValue)
        }
        .onChange(of: speech.isRecording) { newValue in
            self.isRecording = newValue
        }
    }
}
