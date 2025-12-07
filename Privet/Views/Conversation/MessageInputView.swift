//
//  MessageInputView.swift
//  Privet
//

import SwiftUI
import PhotosUI

struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    let onImageSelected: (UIImage) -> Void

    @FocusState private var isFocused: Bool
    @State private var selectedItem: PhotosPickerItem?
    @State private var showAttachmentMenu = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 8) {
                // Кнопка прикрепления
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .frame(width: 36, height: 36)

                // Поле ввода
                HStack {
                    TextField("Сообщение", text: $text, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($isFocused)

                    // Кнопка камеры
                    Button(action: {
                        // TODO: Открыть камеру
                    }) {
                        Image(systemName: "camera")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)

                // Кнопка отправки/записи
                Button(action: {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }) {
                    Image(systemName: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.whatsAppGreen)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
        }
        .onChange(of: selectedItem) { _, newItem in
            print("📷 Photo selected, newItem: \(String(describing: newItem))")
            Task {
                do {
                    if let data = try await newItem?.loadTransferable(type: Data.self) {
                        print("📷 Data loaded, size: \(data.count) bytes")
                        if let image = UIImage(data: data) {
                            print("📷 UIImage created successfully, size: \(image.size)")
                            await MainActor.run {
                                onImageSelected(image)
                                selectedItem = nil
                            }
                        } else {
                            print("❌ Failed to create UIImage from data")
                        }
                    } else {
                        print("❌ Failed to load data from selected item")
                    }
                } catch {
                    print("❌ Error loading image: \(error)")
                }
            }
        }
    }
}

// Версия с default значением для обратной совместимости
extension MessageInputView {
    init(text: Binding<String>, onSend: @escaping () -> Void) {
        self._text = text
        self.onSend = onSend
        self.onImageSelected = { _ in }
    }
}

#Preview {
    VStack {
        Spacer()
        MessageInputView(text: .constant(""), onSend: {}, onImageSelected: { _ in })
        MessageInputView(text: .constant("Привет!"), onSend: {}, onImageSelected: { _ in })
    }
}
