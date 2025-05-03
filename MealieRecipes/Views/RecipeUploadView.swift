import SwiftUI
import PhotosUI
import UIKit

struct RecipeUploadView: View {
    private enum UploadState {
        case idle
        case uploading
        case success
        case failure
    }

    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var recipeURL: String = ""
    @State private var uploadState: UploadState = .idle
    @State private var statusDelayExpired = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(LocalizedStringProvider.localized("upload_recipe"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top)

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LocalizedStringProvider.localized("upload_url_section_title"))
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)

                            Text(LocalizedStringProvider.localized("enter_recipe_url_hint"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField(
                                LocalizedStringProvider.localized("image_placeholder_url"),
                                text: $recipeURL
                            )
                            .textFieldStyle(.roundedBorder)

                            Button {
                                uploadFromURL()
                            } label: {
                                Label(
                                    LocalizedStringProvider.localized("upload_from_url"),
                                    systemImage: "link"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(recipeURL.isEmpty || uploadState == .uploading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LocalizedStringProvider.localized("upload_image_section_title"))
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)

                            Text(LocalizedStringProvider.localized("image_upload_hint"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack {
                                Spacer()
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    Label(LocalizedStringProvider.localized("select_image"), systemImage: "photo")
                                }
                                .buttonStyle(.borderedProminent)
                                Spacer()
                            }

                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            if uploadState == .uploading {
                                ProgressView(LocalizedStringProvider.localized("uploading_image"))
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.accentColor)
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringProvider.localized("openai_hint_title"))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text(LocalizedStringProvider.localized("openai_hint_message"))
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }

                    Spacer()
                }
                .padding()
            }

            // ✅ Upload-Statusanzeige nur NACH Ablauf der Sperrzeit
            if statusDelayExpired && (uploadState == .success || uploadState == .failure) {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 16) {
                    Image(systemName: uploadState == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(uploadState == .success ? .green : .red)

                    Text(uploadState == .success
                         ? LocalizedStringProvider.localized("upload_success")
                         : LocalizedStringProvider.localized("upload_failed"))
                    .font(.headline)
                    .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.85))
                .cornerRadius(20)
                .transition(.scale)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            uploadState = .idle
            statusDelayExpired = false

            // ✅ Statusanzeige erst nach 5 Sekunden erlauben
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                statusDelayExpired = true
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                await handleImageSelection(newItem)
            }
        }
    }

    private func handleImageSelection(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            showResult(success: false)
            return
        }

        selectedImage = image
        uploadState = .uploading
        defer { if uploadState == .uploading { uploadState = .idle } }

        do {
            _ = try await uploadImageWithHeaders(image)
            showResult(success: true)
        } catch {
            print("❌ Upload-Fehler: \(error.localizedDescription)")
            showResult(success: false)
        }
    }

    private func uploadFromURL() {
        guard !recipeURL.isEmpty else { return }

        uploadState = .uploading
        Task {
            defer { if uploadState == .uploading { uploadState = .idle } }

            do {
                _ = try await APIService.shared.uploadRecipeFromURL(url: recipeURL)
                showResult(success: true)
            } catch {
                print("❌ Upload-Fehler: \(error.localizedDescription)")
                showResult(success: false)
            }
        }
    }

    private func showResult(success: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                uploadState = success ? .success : .failure
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                uploadState = .idle
            }
            resetForm()
        }
    }

    private func resetForm() {
        recipeURL = ""
        selectedImage = nil
        selectedItem = nil
    }

    private func uploadImageWithHeaders(_ image: UIImage) async throws -> String {
        guard let baseURL = APIService.shared.getBaseURL(),
              let token = APIService.shared.getToken() else {
            throw URLError(.badURL)
        }

        let optionalHeaders = APIService.shared.getOptionalHeaders

        var components = URLComponents(url: baseURL.appendingPathComponent("api/recipes/create/image"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "translateLanguage", value: "de-DE")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        for (key, value) in optionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "UploadError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: LocalizedStringProvider.localized("image_conversion_error")
            ])
        }

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"images\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        print("🖼️ Bild-Upload Status: \(httpResponse.statusCode)")
        print("📦 Antwort: \(String(data: data, encoding: .utf8) ?? "(keine Antwort)")")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "UploadError", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: String(
                    format: LocalizedStringProvider.localized("upload_http_error"),
                    httpResponse.statusCode
                )
            ])
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\""))) ?? ""
    }
}

// MARK: - Data-Erweiterung für Multipart

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
