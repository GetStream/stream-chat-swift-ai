//
//  PhotoLibraryService.swift
//  StreamChatAI
//
//  Created by Martin Mitrevski on 26.10.25.
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
                if let error = info?[PHImageErrorKey] as? NSError,
                   error.domain == PHPhotosErrorDomain,
                   error.code == Self.missingResourceErrorCode {
                    if fallbackRequested { return }
                    fallbackRequested = true
                    self.fetchFullSizeData(for: asset, resume: resume)
                    return
                }
                
                if (info?[PHImageCancelledKey] as? Bool) == true {
                    resume(nil)
                    return
                }
                
                if let error = info?[PHImageErrorKey] as? Error {
                    print("PhotoLibraryService data fetch error: \(error.localizedDescription)")
                    resume(nil)
                    return
                }
                
                if let data {
                    resume(data)
                    return
                }
                
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                    return
                }
                
                if fallbackRequested { return }
                fallbackRequested = true
                self.fetchFullSizeData(for: asset, resume: resume)
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
                if let error = info?[PHImageErrorKey] as? NSError,
                   error.domain == PHPhotosErrorDomain,
                   error.code == Self.missingResourceErrorCode {
                    if fallbackRequested { return }
                    fallbackRequested = true
                    self.fetchFullSizeThumbnail(for: asset, resume: resume)
                    return
                }
                
                if (info?[PHImageCancelledKey] as? Bool) == true {
                    resume(nil)
                    return
                }
                
                if let error = info?[PHImageErrorKey] as? Error {
                    print("PhotoLibraryService thumbnail error: \(error.localizedDescription)")
                    resume(nil)
                    return
                }
                
                if let image {
                    resume(image)
                    return
                }
                
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                    return
                }
                
                if fallbackRequested { return }
                fallbackRequested = true
                self.fetchFullSizeThumbnail(for: asset, resume: resume)
            }
        }
    }
    
    private func fetchFullSizeData(for asset: PHAsset, resume: @escaping (Data?) -> Void) {
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
                print("PhotoLibraryService full-size data error: \(error.localizedDescription)")
                resume(nil)
                return
            }
            resume(collected.isEmpty ? nil : collected)
        }
    }
    
    private func fetchFullSizeThumbnail(for asset: PHAsset, resume: @escaping (UIImage?) -> Void) {
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
                print("PhotoLibraryService full-size thumbnail error: \(error.localizedDescription)")
                resume(nil)
                return
            }
            
            guard !collected.isEmpty else {
                resume(nil)
                return
            }
            
            guard let image = UIImage(data: collected) else {
                resume(nil)
                return
            }
            
            resume(image)
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
