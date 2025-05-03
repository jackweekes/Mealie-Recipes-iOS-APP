import SwiftUI

struct SetupView: View {
    var isInitialSetup: Bool = true
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var settings = AppSettings.shared
    @State private var tempServerURL: String = ""
    @State private var tempToken: String = ""
    @State private var tempHouseholdId: String = "Family"
    @State private var tempShoppingListId: String = ""
    @State private var tempSendOptionalHeaders: Bool = false

    @State private var optionalHeaderKey1: String = ""
    @State private var optionalHeaderValue1: String = ""
    @State private var optionalHeaderKey2: String = ""
    @State private var optionalHeaderValue2: String = ""
    @State private var optionalHeaderKey3: String = ""
    @State private var optionalHeaderValue3: String = ""

    @State private var isLoadingShoppingListId = false
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        InputField(title: "Server URL", text: $tempServerURL)
                            .keyboardType(.URL)
                            .textContentType(.URL)

                        SecureFieldView(title: "Token", text: $tempToken)
                        InputField(title: "Household ID", text: $tempHouseholdId)

                        if isLoadingShoppingListId {
                            ProgressView(LocalizedStringProvider.localized("loading_shopping_list_id"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            InputField(title: "Shopping List ID", text: $tempShoppingListId)
                        }
                    }

                    Toggle(LocalizedStringProvider.localized("send_optional_headers"), isOn: $tempSendOptionalHeaders)

                    if tempSendOptionalHeaders {
                        Group {
                            InputField(title: "Header 1 Name", text: $optionalHeaderKey1)
                            InputField(title: "Header 1 Value", text: $optionalHeaderValue1)
                            InputField(title: "Header 2 Name", text: $optionalHeaderKey2)
                            InputField(title: "Header 2 Value", text: $optionalHeaderValue2)
                            InputField(title: "Header 3 Name", text: $optionalHeaderKey3)
                            InputField(title: "Header 3 Value", text: $optionalHeaderValue3)
                        }
                    }

                    // MARK: - Sprache
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringProvider.localized("language"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Menu {
                            ForEach(["de", "en"], id: \.self) { code in
                                Button(action: {
                                    settings.selectedLanguage = code
                                }) {
                                    HStack {
                                        Text(languageName(for: code))
                                        if settings.selectedLanguage == code {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(languageName(for: settings.selectedLanguage))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                        }
                    }

                    // MARK: - Speichern
                    Button(action: {
                        saveSettings()
                        if !isInitialSetup {
                            dismiss()
                        }
                    }) {
                        Text(isInitialSetup
                             ? LocalizedStringProvider.localized("save_and_start")
                             : LocalizedStringProvider.localized("save_changes"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(tempServerURL.isEmpty || tempToken.isEmpty || tempHouseholdId.isEmpty)

                    if !isInitialSetup {
                        Button(role: .destructive) {
                            showResetConfirmation = true
                        } label: {
                            Text(LocalizedStringProvider.localized("reset_app"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isInitialSetup
                             ? LocalizedStringProvider.localized("initial_setup")
                             : LocalizedStringProvider.localized("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .id(settings.selectedLanguage)
            .onAppear(perform: loadSettings)
            .alert(LocalizedStringProvider.localized("confirm_reset"), isPresented: $showResetConfirmation) {
                Button(LocalizedStringProvider.localized("cancel"), role: .cancel) {}
                Button(LocalizedStringProvider.localized("reset"), role: .destructive) {
                    resetAppSettings()
                    dismiss()
                }
            } message: {
                Text(LocalizedStringProvider.localized("reset_warning"))
            }
        }
    }

    // MARK: - Helper Views

    private func InputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func SecureFieldView(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            SecureField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func languageName(for code: String) -> String {
        switch code {
        case "de": return "Deutsch"
        case "en": return "English"
        default: return code
        }
    }

    // MARK: - Settings

    private func saveSettings() {
        settings.serverURL = tempServerURL
        settings.token = tempToken
        settings.householdId = tempHouseholdId
        settings.sendOptionalHeaders = tempSendOptionalHeaders
        settings.optionalHeaderKey1 = optionalHeaderKey1
        settings.optionalHeaderValue1 = optionalHeaderValue1
        settings.optionalHeaderKey2 = optionalHeaderKey2
        settings.optionalHeaderValue2 = optionalHeaderValue2
        settings.optionalHeaderKey3 = optionalHeaderKey3
        settings.optionalHeaderValue3 = optionalHeaderValue3

        if tempShoppingListId.isEmpty,
           let url = URL(string: tempServerURL) {
            isLoadingShoppingListId = true
            var headers: [String: String] = [:]
            if tempSendOptionalHeaders {
                headers[optionalHeaderKey1] = optionalHeaderValue1
                headers[optionalHeaderKey2] = optionalHeaderValue2
                headers[optionalHeaderKey3] = optionalHeaderValue3
            }

            APIService.shared.configure(baseURL: url, token: tempToken, optionalHeaders: headers)

            Task {
                do {
                    struct TempShoppingItem: Decodable {
                        let shoppingListId: String
                    }
                    struct TempResponse: Decodable {
                        let items: [TempShoppingItem]
                    }

                    let requestURL = url.appendingPathComponent("api/households/shopping/items")
                    var request = URLRequest(url: requestURL)
                    request.setValue("Bearer \(tempToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    for (key, value) in headers where !key.isEmpty && !value.isEmpty {
                        request.setValue(value, forHTTPHeaderField: key)
                    }

                    let (data, _) = try await URLSession.shared.data(for: request)
                    let response = try JSONDecoder().decode(TempResponse.self, from: data)
                    if let id = response.items.first?.shoppingListId {
                        settings.shoppingListId = id
                        tempShoppingListId = id
                        print("✅ ShoppingListId automatisch gesetzt: \(id)")
                    }
                } catch {
                    print("⚠️ Konnte ShoppingListId nicht laden: \(error)")
                }
                isLoadingShoppingListId = false
            }
        } else {
            settings.shoppingListId = tempShoppingListId
        }
    }

    private func loadSettings() {
        tempServerURL = settings.serverURL
        tempToken = settings.token
        tempHouseholdId = settings.householdId
        tempShoppingListId = settings.shoppingListId
        tempSendOptionalHeaders = settings.sendOptionalHeaders
        optionalHeaderKey1 = settings.optionalHeaderKey1
        optionalHeaderValue1 = settings.optionalHeaderValue1
        optionalHeaderKey2 = settings.optionalHeaderKey2
        optionalHeaderValue2 = settings.optionalHeaderValue2
        optionalHeaderKey3 = settings.optionalHeaderKey3
        optionalHeaderValue3 = settings.optionalHeaderValue3
    }

    private func resetAppSettings() {
        settings.serverURL = ""
        settings.token = ""
        settings.householdId = "Family"
        settings.shoppingListId = ""
        settings.sendOptionalHeaders = false
        settings.optionalHeaderKey1 = ""
        settings.optionalHeaderValue1 = ""
        settings.optionalHeaderKey2 = ""
        settings.optionalHeaderValue2 = ""
        settings.optionalHeaderKey3 = ""
        settings.optionalHeaderValue3 = ""
    }
}
