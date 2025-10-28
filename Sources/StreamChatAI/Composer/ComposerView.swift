//
//  ComposerView.swift
//  StreamChatAI
//
//  Created by Martin Mitrevski on 24.10.25.
//

import Photos
import PhotosUI
import SwiftUI
import UIKit

@available(iOS 16, *)
public struct ComposerView: View {
    @Binding var text: String
    
    var onMessageSend: (MessageData) -> Void
    
    @State private var sheetShown = false
    @State private var attachments: [URL] = []
    @State private var selectedAssetURLs: [String: URL] = [:]
    @State private var temporaryAttachmentURLs: Set<URL> = []
    
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
            
            VStack(spacing: 16) {
                if !attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(attachments, id: \.self) { url in
                                SelectedAttachmentThumbnail(url: url) {
                                    withAnimation {
                                        removeAttachment(url)
                                    }
                                }
                            }
                        }
                    }
                }
                
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
                            onMessageSend(.init(text: text, attachments: attachments))
                            cleanupTemporaryAttachmentFiles(at: Array(temporaryAttachmentURLs))
                            temporaryAttachmentURLs.removeAll()
                            attachments.removeAll()
                            selectedAssetURLs.removeAll()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22)
                        }
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
            ComposerPickerView(
                attachments: $attachments,
                selectedAssetURLs: $selectedAssetURLs,
                temporaryAttachmentURLs: $temporaryAttachmentURLs
            )
                .presentationDetents([.medium, .large])
        }
    }
    
    @MainActor
    private func removeAttachment(_ url: URL) {
        if let assetEntry = selectedAssetURLs.first(where: { $0.value == url }) {
            selectedAssetURLs.removeValue(forKey: assetEntry.key)
        }
        
        if temporaryAttachmentURLs.contains(url) {
            cleanupTemporaryAttachmentFiles(at: [url])
            temporaryAttachmentURLs.remove(url)
        }
        
        attachments.removeAll(where: { $0 == url })
    }
}

@available(iOS 16, *)
struct ComposerPickerView: View {
    @Binding var attachments: [URL]
    @Binding var selectedAssetURLs: [String: URL]
    @Binding var temporaryAttachmentURLs: Set<URL>
    
    @StateObject private var photoLibrary = PhotoLibraryService()
    @State private var allPhotosSelection: [PhotosPickerItem] = []
    @State private var cameraPresented = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                PhotosPicker(
                    selection: $allPhotosSelection,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Text("All Photos")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Capsule())
                }
                .padding()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button {
                        cameraPresented = true
                    } label: {
                        AttachmentTile {
                            Image(systemName: "camera")
                                .fontWeight(.semibold)
                                .foregroundStyle(.black)
                        }
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    
                    ForEach(photoLibrary.recentAssets, id: \.localIdentifier) { asset in
                        RecentPhotoThumbnail(
                            asset: asset,
                            service: photoLibrary,
                            isSelected: selectedAssetURLs[asset.localIdentifier] != nil
                        ) { change in
                            switch change {
                            case .select(let attachment):
                                selectAsset(assetID: asset.localIdentifier, attachment: attachment)
                            case .deselect:
                                deselectAsset(assetID: asset.localIdentifier)
                            case .failed:
                                deselectAsset(assetID: asset.localIdentifier)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
        }
        .task {
            await photoLibrary.prepare(limit: 10)
        }
        .onChange(of: allPhotosSelection) { newItems in
            guard !newItems.isEmpty else { return }
            
            Task {
                for item in newItems {
                    if let identifier = item.itemIdentifier,
                       let asset = photoLibrary.asset(for: identifier),
                       let url = await photoLibrary.fileURL(for: asset) {
                        await MainActor.run {
                            appendAttachment(.init(url: url, isTemporary: false))
                        }
                        continue
                    }
                    
                    if let url = try? await item.loadTransferable(type: URL.self) {
                        await MainActor.run {
                            appendAttachment(.init(url: url, isTemporary: false))
                        }
                        continue
                    }
                    
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let tempURL = writeAttachmentDataToTemporaryURL(data) {
                        await MainActor.run {
                            appendAttachment(.init(url: tempURL, isTemporary: true))
                        }
                    }
                }
                
                await MainActor.run {
                    allPhotosSelection = []
                }
            }
        }
        .fullScreenCover(isPresented: $cameraPresented) {
            CameraPicker(isPresented: $cameraPresented) { result in
                appendAttachment(result)
            }
        }
        .onChange(of: attachments) { newValue in
            if newValue.isEmpty {
                selectedAssetURLs.removeAll()
                cleanupTemporaryAttachmentFiles(at: Array(temporaryAttachmentURLs))
                temporaryAttachmentURLs.removeAll()
            }
        }
    }
    
    @MainActor
    private func selectAsset(assetID: String, attachment: AttachmentLocation) {
        guard selectedAssetURLs[assetID] == nil else { return }
        selectedAssetURLs[assetID] = attachment.url
        appendAttachment(attachment)
    }
    
    @MainActor
    private func deselectAsset(assetID: String) {
        guard let removed = selectedAssetURLs.removeValue(forKey: assetID) else { return }
        if temporaryAttachmentURLs.contains(removed) {
            cleanupTemporaryAttachmentFiles(at: [removed])
            temporaryAttachmentURLs.remove(removed)
        }
        if let index = attachments.firstIndex(of: removed) {
            attachments.remove(at: index)
        }
    }
    
    @MainActor
    private func appendAttachment(_ attachment: AttachmentLocation) {
        attachments.append(attachment.url)
        if attachment.isTemporary {
            temporaryAttachmentURLs.insert(attachment.url)
        } else {
            temporaryAttachmentURLs.remove(attachment.url)
        }
    }
}

@available(iOS 16, *)
private struct RecentPhotoThumbnail: View {
    enum SelectionChange {
        case select(AttachmentLocation)
        case deselect
        case failed
    }
    
    let asset: PHAsset
    @ObservedObject var service: PhotoLibraryService
    let isSelected: Bool
    let onSelectionChange: (SelectionChange) -> Void
    
    @State private var image: UIImage?
    @State private var didFail = false
    @State private var isFetchingAttachment = false
    
    var body: some View {
        Button {
            Task {
                if isSelected {
                    await MainActor.run {
                        didFail = false
                        onSelectionChange(.deselect)
                    }
                    return
                }
                
                guard !isFetchingAttachment else { return }
                await MainActor.run {
                    didFail = false
                    isFetchingAttachment = true
                }
                
                var attachment: AttachmentLocation?
                if let url = await service.fileURL(for: asset) {
                    attachment = .init(url: url, isTemporary: false)
                } else if let data = await service.data(for: asset),
                          let tempURL = writeAttachmentDataToTemporaryURL(data) {
                    attachment = .init(url: tempURL, isTemporary: true)
                }
                await MainActor.run {
                    isFetchingAttachment = false
                    if let attachment {
                        didFail = false
                        onSelectionChange(.select(attachment))
                    } else {
                        didFail = true
                        onSelectionChange(.failed)
                    }
                }
            }
        } label: {
            AttachmentTile {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .allowsHitTesting(false)
                        .clipped()
                } else if didFail {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .overlay(alignment: .topTrailing) {
                SelectionBadge(isSelected: isSelected)
                    .padding(6)
            }
        }
        .disabled(isFetchingAttachment)
        .task {
            guard image == nil else { return }
            let scale = UIScreen.main.scale
            let size = CGSize(width: 100 * scale, height: 100 * scale)
            if let thumbnail = await service.thumbnail(for: asset, targetSize: size) {
                await MainActor.run {
                    image = thumbnail
                    didFail = false
                }
            } else {
                await MainActor.run {
                    didFail = true
                }
            }
        }
        .onChange(of: isSelected) { selected in
            if !selected {
                didFail = false
            }
        }
    }
}

@available(iOS 16, *)
private struct SelectedAttachmentThumbnail: View {
    let url: URL
    let onRemove: () -> Void
    
    @State private var image: UIImage?
    @State private var didFail = false
    
    var body: some View {
        AttachmentTile {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .allowsHitTesting(false)
                    .clipped()
            } else if didFail {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .shadow(radius: 1)
                    Circle()
                        .fill(Color.black.opacity(0.7))
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .task {
            guard image == nil else { return }
            if let loaded = await loadImage() {
                await MainActor.run {
                    image = loaded
                    didFail = false
                }
            } else {
                await MainActor.run {
                    didFail = true
                }
            }
        }
    }
    
    private func loadImage() async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
    }
}

@available(iOS 16, *)
private struct AttachmentTile<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(UIColor.lightGray).opacity(0.3))
            .overlay {
                content()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        .frame(width: 100, height: 100)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

@available(iOS 16, *)
private struct SelectionBadge: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .shadow(radius: 1)
                Circle()
                    .fill(Color.accentColor)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 16, height: 16)
            }
        }
        .frame(width: 20, height: 20)
    }
}

@available(iOS 16, *)
private struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onCapture: (AttachmentLocation) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            controller.sourceType = .camera
        }
        controller.allowsEditing = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPicker
        
        init(parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { dismiss() }
            
            if let imageURL = info[.imageURL] as? URL {
                DispatchQueue.main.async {
                    self.parent.onCapture(.init(url: imageURL, isTemporary: false))
                }
                return
            }
            
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            guard let image, let data = image.jpegData(compressionQuality: 0.9) else { return }
            guard let url = writeAttachmentDataToTemporaryURL(data) else { return }
            DispatchQueue.main.async {
                self.parent.onCapture(.init(url: url, isTemporary: true))
            }
        }
        
        private func dismiss() {
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }
    }
}

private struct AttachmentLocation {
    let url: URL
    let isTemporary: Bool
}

private func writeAttachmentDataToTemporaryURL(_ data: Data) -> URL? {
    let fileManager = FileManager.default
    let fileURL = fileManager.temporaryDirectory.appendingPathComponent(
        "streamchat-attachment-\(UUID().uuidString).jpg"
    )
    
    let dataToWrite: Data
    if data.starts(with: [0xFF, 0xD8]) {
        dataToWrite = data
    } else if let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.9) {
        dataToWrite = jpegData
    } else {
        return nil
    }
    
    do {
        try dataToWrite.write(to: fileURL, options: [.atomic])
        return fileURL
    } catch {
        print("ComposerView attachment write error: \(error.localizedDescription)")
        return nil
    }
}

private func cleanupTemporaryAttachmentFiles(at urls: [URL]) {
    let fileManager = FileManager.default
    let uniqueURLs = Set(urls.filter { $0.isFileURL })
    
    for url in uniqueURLs {
        do {
            try fileManager.removeItem(at: url)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain,
               error.code == NSFileNoSuchFileError {
                continue
            }
            print("ComposerView attachment cleanup error: \(error.localizedDescription)")
        }
    }
}

public struct MessageData {
    public let text: String
    public let attachments: [URL]
    
    public init(text: String, attachments: [URL] = []) {
        self.text = text
        self.attachments = attachments
    }
}
