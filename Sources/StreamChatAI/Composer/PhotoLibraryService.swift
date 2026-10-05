//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Photos
import UIKit

@MainActor
final class PhotoLibraryService: ObservableObject {
    @Published private(set) var recentAssets: [PHAsset] = []
    
    private let imageManager = PHCachingImageManager()
    private static let missingResourceErrorCode = PHPhotosError.missingResource.rawValue
    
    func prepare(limit: Int = 10) async {
        guard await requestAuthorizationIfNeeded() else {
            recentAssets = []
            return
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = limit
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        recentAssets = assets
    }
    
    func asset(for identifier: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject
    }
    
    func data(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            
            var didResume = false
            var fallbackRequested = false
            func resume(_ data: Data?) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: data)
            }
            
            self.imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                switch Self.outcome(of: info, hasResult: data != nil, request: "data fetch") {
                case .result:
                    resume(data)
                case .failed:
                    resume(nil)
                case .fullSize:
                    if fallbackRequested { return }
                    fallbackRequested = true
                    self.fetchFullSizeData(for: asset, request: "full-size data", resume: resume)
                case .wait:
                    return
                }
            }
        }
    }
    
    func fileURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true
            options.canHandleAdjustmentData = { _ in true }
            
            asset.requestContentEditingInput(with: options) { input, _ in
                continuation.resume(returning: input?.fullSizeImageURL)
            }
        }
    }
    
    func thumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            var didResume = false
            var fallbackRequested = false
            func resume(_ image: UIImage?) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
            
            self.imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                switch Self.outcome(of: info, hasResult: image != nil, request: "thumbnail") {
                case .result:
                    resume(image)
                case .failed:
                    resume(nil)
                case .fullSize:
                    if fallbackRequested { return }
                    fallbackRequested = true
                    self.fetchFullSizeData(for: asset, request: "full-size thumbnail") { data in
                        resume(data.flatMap(UIImage.init(data:)))
                    }
                case .wait:
                    return
                }
            }
        }
    }
    
    /// What to do with what the image manager delivered.
    private enum RequestOutcome {
        /// Use the delivered result.
        case result
        /// Give up.
        case failed
        /// Read the full-size photo instead.
        case fullSize
        /// Wait for a better result than this degraded one.
        case wait
    }
    
    private static func outcome(of info: [AnyHashable: Any]?, hasResult: Bool, request: String) -> RequestOutcome {
        if let error = info?[PHImageErrorKey] as? NSError,
           error.domain == PHPhotosErrorDomain,
           error.code == missingResourceErrorCode {
            return .fullSize
        }
        
        if (info?[PHImageCancelledKey] as? Bool) == true {
            return .failed
        }
        
        if let error = info?[PHImageErrorKey] as? Error {
            print("PhotoLibraryService \(request) error: \(error.localizedDescription)")
            return .failed
        }
        
        if hasResult {
            return .result
        }
        
        if (info?[PHImageResultIsDegradedKey] as? Bool) == true {
            return .wait
        }
        
        return .fullSize
    }
    
    private func fetchFullSizeData(for asset: PHAsset, request: String, resume: @escaping (Data?) -> Void) {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) ?? resources.first else {
            resume(nil)
            return
        }
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        
        var collected = Data()
        PHAssetResourceManager.default().requestData(for: resource, options: options) { chunk in
            collected.append(chunk)
        } completionHandler: { error in
            if let error {
                print("PhotoLibraryService \(request) error: \(error.localizedDescription)")
                resume(nil)
                return
            }
            resume(collected.isEmpty ? nil : collected)
        }
    }
    
    private func requestAuthorizationIfNeeded() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }
}
