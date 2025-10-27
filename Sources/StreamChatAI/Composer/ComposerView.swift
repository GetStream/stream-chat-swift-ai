//
//  ComposerView.swift
//  StreamChatAI
//
//  Created by Martin Mitrevski on 24.10.25.
//

import SwiftUI

@available(iOS 16, *)
public struct ComposerView: View {
    @Binding var text: String
    
    var onMessageSend: (MessageData) -> Void
    
    @State private var sheetShown = false
    
    public init(text: Binding<String>, onMessageSend: @escaping (MessageData) -> Void) {
        _text = text
        self.onMessageSend = onMessageSend
    }
    
    public var body: some View {
        HStack {
            Button {
                sheetShown = true
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(.gray)
                    .fontWeight(.semibold)
            }
            .padding(.all, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(.circle)
            
            HStack {
                TextField("Ask anything", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                
                if text.isEmpty {
                    TranscribeSpeechButton { newText in
                        self.text = newText
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
                } else {
                    Button {
                        onMessageSend(.init(text: text))
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22)
                    }
                }
            }
            .padding(.all, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(24)
        }
        .padding(.all, 8)
        .foregroundStyle(.primary)
        .sheet(isPresented: $sheetShown) {
            ComposerPickerView()
                .presentationDetents([.medium, .large])
        }
    }
}

@available(iOS 16, *)
struct ComposerPickerView: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    
                } label: {
                    Text("All Photos")
                        .padding()
                }
            }
            ScrollView(.horizontal) {
                HStack {
                    Button {
                        
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.lightGray).opacity(0.3))
                            
                            Image(systemName: "camera")
                                .fontWeight(.semibold)
                                .foregroundStyle(.black)
                        }
                        .frame(width: 100, height: 100)
                    }
                }
                .padding()
            }
            Spacer()
        }
    }
}

public struct MessageData {
    public let text: String
//    let attachments: [Attachment] //TODO:
}
