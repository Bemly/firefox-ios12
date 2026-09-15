//
//  FilePickerMediaPicker.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import MobileCoreServices
@preconcurrency import PhotosUI
import UIKit

extension FilePicker {
    // MARK: - Availability
    
    @available(iOS 14.0, *)
    var photoLibraryFilter: PHPickerFilter? {
        let mediaTypes = Set(acceptedTypes.mediaTypes)
        let supportsImages = mediaTypes.contains(kUTTypeImage as String)
        let supportsVideos = mediaTypes.contains(kUTTypeMovie as String)
        
        switch (supportsImages, supportsVideos) {
        case (true, true):
            return .any(of: [.images, .videos])
        case (true, false):
            return .images
        case (false, true):
            return .videos
        case (false, false):
            return nil
        }
    }
    
    var canUsePhotoLibrary: Bool {
        guard !acceptedTypes.mediaTypes.isEmpty else {
            return false
        }
        
        if #available(iOS 14.0, *) {
            return photoLibraryFilter != nil
        }
        
        return UIImagePickerController.isSourceTypeAvailable(.photoLibrary) &&
        !resolvedAvailableMediaTypes(for: .photoLibrary).isEmpty
    }
    
    var canUseCamera: Bool {
        !acceptedTypes.mediaTypes.isEmpty &&
        UIImagePickerController.isSourceTypeAvailable(.camera) &&
        !resolvedAvailableMediaTypes(for: .camera).isEmpty
    }
    
    // MARK: - Media Picker
    
    func presentMediaPicker(sourceType: UIImagePickerController.SourceType) {
        if sourceType == .photoLibrary,
           #available(iOS 14.0, *) {
            presentPhotoLibraryPicker()
            return
        }
        
        presentLegacyMediaPicker(sourceType: sourceType)
    }
    
    @available(iOS 14.0, *)
    private func presentPhotoLibraryPicker() {
        guard let presenter = UIApplication.shared.topViewController(),
              let filter = photoLibraryFilter else {
            finish(with: nil)
            return
        }
        
        var configuration = PHPickerConfiguration()
        configuration.filter = filter
        configuration.preferredAssetRepresentationMode = .current
        configuration.selectionLimit = mode == .multiple ? 0 : 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter.present(picker, animated: true)
        picker.presentationController?.delegate = self
        presentedController = picker
    }
    
    private func presentLegacyMediaPicker(sourceType: UIImagePickerController.SourceType) {
        guard let presenter = UIApplication.shared.topViewController() else {
            finish(with: nil)
            return
        }
        
        let mediaTypes = resolvedAvailableMediaTypes(for: sourceType)
        guard !mediaTypes.isEmpty else {
            finish(with: nil)
            return
        }
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.mediaTypes = mediaTypes
        configureCameraIfNeeded(picker, mediaTypes: mediaTypes, sourceType: sourceType)
        
        presenter.present(picker, animated: true)
        picker.presentationController?.delegate = self
        presentedController = picker
    }
    
    private func configureCameraIfNeeded(
        _ picker: UIImagePickerController,
        mediaTypes: [String],
        sourceType: UIImagePickerController.SourceType
    ) {
        guard sourceType == .camera else {
            return
        }
        
        picker.modalPresentationStyle = .fullScreen
        if let preferredDevice = resolvedCameraDevice(),
           UIImagePickerController.isCameraDeviceAvailable(preferredDevice) {
            picker.cameraDevice = preferredDevice
        }
        if mediaTypes == [kUTTypeMovie as String] {
            picker.cameraCaptureMode = .video
        }
    }
    
    func resolvedAvailableMediaTypes(
        for sourceType: UIImagePickerController.SourceType
    ) -> [String] {
        let availableTypes = Set(UIImagePickerController.availableMediaTypes(for: sourceType) ?? [])
        return acceptedTypes.mediaTypes.filter { availableTypes.contains($0) }
    }
    
    private func resolvedCameraDevice() -> UIImagePickerController.CameraDevice? {
        switch capture {
        case .user:
            return .front
        case .environment:
            return .rear
        case .any, .none:
            return nil
        }
    }
    
    // MARK: - Result Preparation
    
    func prepareMediaResult(
        mediaURL: URL?,
        imageURL: URL?,
        imageData: Data?,
        completion: @escaping (SelectionResult?) -> Void
    ) {
        let stagingDirectoryURL = self.stagingDirectoryURL

        DispatchQueue.global(qos: .userInitiated).async {
            let result: SelectionResult?
            if let mediaURL {
                result = try? Self.stageFiles(from: [mediaURL], in: stagingDirectoryURL)
            } else if let imageURL {
                result = try? Self.stageFiles(from: [imageURL], in: stagingDirectoryURL)
            } else if let imageData {
                result = try? Self.stageImageData(imageData, in: stagingDirectoryURL)
            } else {
                result = nil
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    @available(iOS 14.0, *)
    func preparePhotoLibraryResult(from results: [PHPickerResult], completion: @escaping (SelectionResult?) -> Void) {
        let selectedResults = mode == .multiple ? results : Array(results.prefix(1))
        guard !selectedResults.isEmpty else {
            completion(nil)
            return
        }

        do {
            try Self.prepareDirectory(stagingDirectoryURL)
        } catch {
            completion(nil)
            return
        }

        let directory = stagingDirectoryURL
        let mediaTypes = acceptedTypes.mediaTypes
        var stagedFiles: [String] = []

        // Stage each picked item sequentially; stageItemProvider is callback-based.
        func processNext(_ index: Int) {
            guard index < selectedResults.count else {
                let result = stagedFiles.isEmpty
                    ? nil
                    : SelectionResult(files: stagedFiles, filesInWebKitDirectory: [])
                DispatchQueue.main.async {
                    completion(result)
                }
                return
            }

            Self.stageItemProvider(
                selectedResults[index].itemProvider,
                acceptedMediaTypes: mediaTypes,
                in: directory
            ) { stagedURL in
                if let stagedURL {
                    stagedFiles.append(stagedURL.path)
                }
                processNext(index + 1)
            }
        }

        processNext(0)
    }
}
