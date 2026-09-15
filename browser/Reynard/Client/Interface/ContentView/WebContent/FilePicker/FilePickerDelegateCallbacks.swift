//
//  FilePickerDelegateCallbacks.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

@preconcurrency import PhotosUI
import UIKit

extension FilePicker: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        dismissPicker(controller) { picker in
            picker.prepareDocumentResult(from: urls) { result in
                picker.finish(with: result?.promptResult)
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        dismissPicker(controller) { picker in
            picker.finish(with: nil)
        }
    }
}

@available(iOS 14.0, *)
extension FilePicker: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismissPicker(picker) { filePicker in
            filePicker.preparePhotoLibraryResult(from: results) { result in
                filePicker.finish(with: result?.promptResult)
            }
        }
    }
}

extension FilePicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismissPicker(picker) { filePicker in
            filePicker.finish(with: nil)
        }
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let mediaURL = info[.mediaURL] as? URL
        let imageURL = info[.imageURL] as? URL
        let imageData = (info[.originalImage] as? UIImage)?.jpegData(compressionQuality: UX.imageCompressionQuality)

        dismissPicker(picker) { filePicker in
            filePicker.prepareMediaResult(mediaURL: mediaURL, imageURL: imageURL, imageData: imageData) { result in
                filePicker.finish(with: result?.promptResult)
            }
        }
    }
}

extension FilePicker: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard !isCompletingPicker else { return }
        presentedController = nil
        finish(with: nil)
    }
}
