//
//  ImagePickerService.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import PhotosUI
import UIKit

class ImagePickerService: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isPresented = false
    
    func pickImage() {
        isPresented = true
    }
    
    func uploadImage(_ image: UIImage) -> AnyPublisher<String, Error> {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return Fail(error: NSError(domain: "ImagePickerService", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片压缩失败"]))
                .eraseToAnyPublisher()
        }
        
        return APIService.shared.uploadImage(imageData)
            .map { $0.url }
            .eraseToAnyPublisher()
    }
}

// SwiftUI包装器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

