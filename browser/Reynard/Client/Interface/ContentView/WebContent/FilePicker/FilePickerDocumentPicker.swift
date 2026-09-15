//
//  FilePickerDocumentPicker.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

extension FilePicker {
    func presentDocumentPicker() {
        guard let presenter = UIApplication.shared.topViewController() else {
            finish(with: nil)
            return
        }
        
        let picker = documentPicker()
        picker.delegate = self
        picker.allowsMultipleSelection = mode == .multiple
        presenter.present(picker, animated: true)
        picker.presentationController?.delegate = self
        presentedController = picker
    }
    
    private func documentPicker() -> UIDocumentPickerViewController {
        if #available(iOS 14.0, *) {
            if mode == .folder {
                return UIDocumentPickerViewController(
                    forOpeningContentTypes: [UTType.folder],
                    asCopy: false
                )
            }
            
            let contentTypes = acceptedTypes.documentTypeIdentifiers.compactMap { UTType($0) }
            return UIDocumentPickerViewController(
                forOpeningContentTypes: contentTypes.isEmpty ? [UTType.item] : contentTypes
            )
        }
        
        let legacyTypes = acceptedTypes.legacyDocumentTypes.isEmpty
        ? [kUTTypeItem as String]
        : acceptedTypes.legacyDocumentTypes
        return UIDocumentPickerViewController(documentTypes: legacyTypes, in: .open)
    }
    
    func prepareDocumentResult(from urls: [URL], completion: @escaping (SelectionResult?) -> Void) {
        let selectedURLs = mode == .multiple ? urls : Array(urls.prefix(1))
        let mode = self.mode
        let stagingDirectoryURL = self.stagingDirectoryURL

        DispatchQueue.global(qos: .userInitiated).async {
            let result: SelectionResult?
            switch mode {
            case .folder:
                if let url = selectedURLs.first {
                    result = try? Self.stageFolder(from: url, in: stagingDirectoryURL)
                } else {
                    result = nil
                }
            case .single, .multiple:
                result = try? Self.stageFiles(from: selectedURLs, in: stagingDirectoryURL)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
