//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import SwiftUI

public struct SuggestionsView: View {
    
    var suggestions: [String]
    var height: CGFloat
    var itemMaxWidth: CGFloat
    var onMessageSend: (MessageData) -> ()
    
    public init(
        suggestions: [String],
        height: CGFloat = 100,
        itemMaxWidth: CGFloat = 160,
        onMessageSend: @escaping (MessageData) -> ()
    ) {
        self.suggestions = suggestions
        self.height = height
        self.itemMaxWidth = itemMaxWidth
        self.onMessageSend = onMessageSend
    }
    
    public var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(suggestions, id: \.self) { option in
                    Button {
                        onMessageSend(.init(text: option))
                    } label: {
                        Text(option)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: itemMaxWidth)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                    }
                }
            }
            .padding()
        }
        .frame(height: height)
    }
}

