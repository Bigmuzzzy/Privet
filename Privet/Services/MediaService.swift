//
//  MediaService.swift
//  Privet
//

import Foundation
import SwiftUI
import PhotosUI
import AVFoundation
import Combine

class MediaService: ObservableObject {
    static let shared = MediaService()

    @Published var uploadProgress: Double = 0
    @Published var isUploading: Bool = false

    // MARK: - Server Configuration
    // Измените на адрес вашего сервера
    #if DEBUG
    private let serverBaseURL = "http://localhost:3000"
    #else
    private let serverBaseURL = "https://your-server.com" // Замените на ваш домен
    #endif

    private init() {}

    // MARK: - Upload Image

    func uploadImage(_ image: UIImage, chatId: String, messageId: String) async throws -> String {
        print("📷 MediaService.uploadImage called")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to compress image to JPEG")
            throw MediaError.compressionFailed
        }
        print("📷 Image compressed to JPEG, size: \(imageData.count) bytes")

        return try await uploadToServer(
            data: imageData,
            filename: "\(messageId).jpg",
            mimeType: "image/jpeg",
            endpoint: "/api/media/upload/image",
            fieldName: "image",
            chatId: chatId,
            messageId: messageId
        )
    }

    // MARK: - Upload Video

    func uploadVideo(url: URL, chatId: String, messageId: String) async throws -> String {
        let videoData = try Data(contentsOf: url)
        return try await uploadToServer(
            data: videoData,
            filename: "\(messageId).mp4",
            mimeType: "video/mp4",
            endpoint: "/api/media/upload/video",
            fieldName: "video",
            chatId: chatId,
            messageId: messageId
        )
    }

    // MARK: - Upload to Custom Server

    private func uploadToServer(
        data: Data,
        filename: String,
        mimeType: String,
        endpoint: String,
        fieldName: String,
        chatId: String,
        messageId: String
    ) async throws -> String {
        print("📷 uploadToServer called, data size: \(data.count), endpoint: \(endpoint)")

        guard let url = URL(string: serverBaseURL + endpoint) else {
            throw MediaError.invalidData
        }

        await MainActor.run {
            self.isUploading = true
            self.uploadProgress = 0
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add chatId field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chatId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(chatId)\r\n".data(using: .utf8)!)

        // Add messageId field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"messageId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(messageId)\r\n".data(using: .utf8)!)

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("📷 Starting upload to \(url.absoluteString)...")

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)

            await MainActor.run {
                self.isUploading = false
                self.uploadProgress = 1.0
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw MediaError.uploadFailed
            }

            print("📷 Server response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                print("❌ Server error: \(errorMessage)")
                throw MediaError.uploadFailed
            }

            // Parse response
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            guard let imageURL = json?["url"] as? String else {
                print("❌ Invalid server response")
                throw MediaError.uploadFailed
            }

            print("📷 Upload successful, URL: \(imageURL)")
            return imageURL

        } catch {
            await MainActor.run {
                self.isUploading = false
                self.uploadProgress = 0
            }
            print("❌ Upload failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Generate Thumbnail

    func generateVideoThumbnail(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }

    // MARK: - Compress Image

    func compressImage(_ image: UIImage, maxSize: CGFloat = 1024) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)

        if ratio >= 1 {
            return image
        }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

enum MediaError: LocalizedError {
    case compressionFailed
    case uploadFailed
    case invalidData

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Не удалось сжать изображение"
        case .uploadFailed:
            return "Ошибка загрузки файла"
        case .invalidData:
            return "Неверный формат данных"
        }
    }
}
