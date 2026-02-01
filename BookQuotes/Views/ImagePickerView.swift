//
//  ImagePickerView.swift
//  BookQuotes
//
//  SwiftUI wrapper for UIImagePickerController.
//  Supports both camera and photo library sources.
//

import SwiftUI
import UIKit

/// A SwiftUI wrapper for UIImagePickerController
/// Supports both camera capture and photo library selection
struct ImagePickerView: UIViewControllerRepresentable {
    // MARK: - Properties
    
    /// The source type (camera or photo library)
    let sourceType: UIImagePickerController.SourceType
    
    /// Callback when an image is selected
    let onImageSelected: (UIImage) -> Void
    
    /// Callback when the picker is cancelled
    let onCancel: () -> Void
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        
        // For camera, prefer rear camera
        if sourceType == .camera {
            picker.cameraDevice = .rear
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Update source type if it changed
        if uiViewController.sourceType != sourceType {
            uiViewController.sourceType = sourceType
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, onCancel: onCancel)
    }
    
    // MARK: - Coordinator
    
    /// Coordinator to handle UIImagePickerController delegate methods
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        let onCancel: () -> Void
        
        init(onImageSelected: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImageSelected = onImageSelected
            self.onCancel = onCancel
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Prefer the original image
            if let image = info[.originalImage] as? UIImage {
                // Fix orientation if needed
                let fixedImage = fixOrientation(image)
                onImageSelected(fixedImage)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
        
        /// Fixes the orientation of camera-captured images
        /// Camera images often have incorrect orientation metadata
        private func fixOrientation(_ image: UIImage) -> UIImage {
            // If orientation is already correct, return as-is
            if image.imageOrientation == .up {
                return image
            }
            
            // Redraw the image with correct orientation
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return normalizedImage ?? image
        }
    }
}

// MARK: - Helper Extension

extension UIImagePickerController.SourceType {
    /// Check if this source type is available on the current device
    static func isAvailable(_ sourceType: UIImagePickerController.SourceType) -> Bool {
        UIImagePickerController.isSourceTypeAvailable(sourceType)
    }
}

// MARK: - Preview

#Preview("Photo Library") {
    ImagePickerView(
        sourceType: .photoLibrary,
        onImageSelected: { image in
            print("Selected image: \(image.size)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
