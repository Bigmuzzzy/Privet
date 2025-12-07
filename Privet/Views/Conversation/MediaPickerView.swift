//
//  MediaPickerView.swift
//  Privet
//

import SwiftUI
import PhotosUI

struct MediaPickerView: View {
    @Binding var selectedImage: UIImage?
    @Binding var selectedVideoURL: URL?
    @Binding var isPresented: Bool

    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showActionSheet = false

    var body: some View {
        EmptyView()
            .confirmationDialog("Выберите источник", isPresented: $showActionSheet) {
                Button("Камера") {
                    showCamera = true
                }
                Button("Галерея") {
                    // PhotosPicker откроется автоматически
                }
                Button("Отмена", role: .cancel) {
                    isPresented = false
                }
            }
            .photosPicker(isPresented: $isPresented, selection: $selectedItem, matching: .any(of: [.images, .videos]))
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await loadMedia(from: newItem)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
    }

    private func loadMedia(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        // Попробуем загрузить как изображение
        if let data = try? await item.loadTransferable(type: Data.self) {
            if let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
                return
            }
        }

        // Попробуем загрузить как видео
        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
            await MainActor.run {
                selectedVideoURL = movie.url
            }
        }
    }
}

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Image Picker (простой вариант)

struct ImagePicker: View {
    @Binding var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Image(systemName: "photo")
                .font(.system(size: 22))
                .foregroundColor(.gray)
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                    }
                }
            }
        }
    }
}
