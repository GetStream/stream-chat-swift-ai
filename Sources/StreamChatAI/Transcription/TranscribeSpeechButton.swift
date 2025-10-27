//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import SwiftUI

public struct TranscribeSpeechButton: View {
    @StateObject private var speech = SpeechHandler()
    @State private var isRecording = false
    
    private var locale: Locale
    private var silenceTimeout: Double
    
    var onTranscriptChange: (String) -> ()
    
    public init(
        locale: Locale? = nil,
        silenceTimeout: Double = 2.0,
        onTranscriptChange: @escaping (String) -> () = { _ in }
    ) {
        self.locale = locale ?? Locale.current
        self.silenceTimeout = silenceTimeout
        self.onTranscriptChange = onTranscriptChange
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Button {
                if isRecording {
                    speech.stop()
                } else {
                    speech.start()
                }
            } label: {
                Image(systemName: isRecording ? "stop.circle" : "mic")
            }
        }
        .onAppear {
            speech.requestAuthorization()
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
