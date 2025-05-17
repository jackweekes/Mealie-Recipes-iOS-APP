import SwiftUI

struct SetupView: View {
    var isInitialSetup: Bool = true
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings

    @State private var tempLanguage: String = AppSettings.shared.selectedLanguage
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

    @State private var shoppingLists: [ShoppingList] = []
    @State private var isLoadingShoppingLists = false
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
                        InputField(title: "Household", text: $tempHouseholdId)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringProvider.localized("select_shopping_list"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            Menu {
                                ForEach(shoppingLists, id: \.id) { list in
                                    Button(action: {
                                        tempShoppingListId = list.id
                                        print("✅ Selected shopping list: \(list.name)")
                                    }) {
                                        HStack {
                                            Text(list.name)
                                            if list.id == tempShoppingListId {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(
                                        shoppingLists.first(where: { $0.id == tempShoppingListId })?.name
                                        ?? LocalizedStringProvider.localized("no_lists_loaded")
                                    )
                                    .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            }

                            Button(action: {
                                Task {
                                    await fetchShoppingLists()
                                }
                            }) {
                                Group {
                                    if isLoadingShoppingLists {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                            .frame(width: 24, height: 24)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(8)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Circle())
                            }
                            .disabled(tempServerURL.isEmpty || tempToken.isEmpty)
                            .accessibilityLabel(Text(LocalizedStringProvider.localized("reload_lists")))
                        }

                        if tempShoppingListId.isEmpty && shoppingLists.isEmpty {
                            Text(LocalizedStringProvider.localized("no_lists_loaded"))
                                .font(.footnote)
                                .foregroundColor(.gray)
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringProvider.localized("language"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Menu {
                            ForEach(["de", "en"], id: \.self) { code in
                                Button(action: {
                                    tempLanguage = code
                                    LocalizedStringProvider.overrideLanguage = code
                                }) {
                                    HStack {
                                        Text(languageName(for: code))
                                        if tempLanguage == code {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(languageName(for: tempLanguage))
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
            .id(tempLanguage)
            .onAppear {
                loadSettings()
                Task { await fetchShoppingLists() }
            }
            .onDisappear {
                LocalizedStringProvider.overrideLanguage = nil
            }
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
        settings.shoppingListId = tempShoppingListId
        settings.selectedLanguage = tempLanguage
        LocalizedStringProvider.overrideLanguage = nil
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
        tempLanguage = settings.selectedLanguage
        LocalizedStringProvider.overrideLanguage = tempLanguage
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

    private func fetchShoppingLists() async {
        guard !tempServerURL.isEmpty, !tempToken.isEmpty else { return }

        isLoadingShoppingLists = true
        var headers: [String: String] = [:]
        if tempSendOptionalHeaders {
            headers[optionalHeaderKey1] = optionalHeaderValue1
            headers[optionalHeaderKey2] = optionalHeaderValue2
            headers[optionalHeaderKey3] = optionalHeaderValue3
        }

        if let url = URL(string: tempServerURL) {
            APIService.shared.configure(baseURL: url, token: tempToken, optionalHeaders: headers)

            do {
                shoppingLists = try await APIService.shared.fetchShoppingLists()
                if let current = shoppingLists.first(where: { $0.id == tempShoppingListId }) {
                    tempShoppingListId = current.id
                } else if tempShoppingListId.isEmpty {
                    tempShoppingListId = shoppingLists.first?.id ?? ""
                }
            } catch {
                print("❌ Fehler beim Laden der Listen: \(error.localizedDescription)")
            }
        }

        isLoadingShoppingLists = false
    }
}
