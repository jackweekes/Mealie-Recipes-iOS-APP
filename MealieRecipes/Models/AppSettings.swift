import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    @Published var token: String {
        didSet { UserDefaults.standard.set(token, forKey: "token") }
    }

    @Published var householdId: String {
        didSet { UserDefaults.standard.set(householdId, forKey: "householdId") }
    }

    @Published var shoppingListId: String {
        didSet { UserDefaults.standard.set(shoppingListId, forKey: "shoppingListId") }
    }

    @Published var sendOptionalHeaders: Bool {
        didSet { UserDefaults.standard.set(sendOptionalHeaders, forKey: "sendOptionalHeaders") }
    }

    @Published var optionalHeaderKey1: String {
        didSet { UserDefaults.standard.set(optionalHeaderKey1, forKey: "optionalHeaderKey1") }
    }

    @Published var optionalHeaderValue1: String {
        didSet { UserDefaults.standard.set(optionalHeaderValue1, forKey: "optionalHeaderValue1") }
    }

    @Published var optionalHeaderKey2: String {
        didSet { UserDefaults.standard.set(optionalHeaderKey2, forKey: "optionalHeaderKey2") }
    }

    @Published var optionalHeaderValue2: String {
        didSet { UserDefaults.standard.set(optionalHeaderValue2, forKey: "optionalHeaderValue2") }
    }

    @Published var optionalHeaderKey3: String {
        didSet { UserDefaults.standard.set(optionalHeaderKey3, forKey: "optionalHeaderKey3") }
    }

    @Published var optionalHeaderValue3: String {
        didSet { UserDefaults.standard.set(optionalHeaderValue3, forKey: "optionalHeaderValue3") }
    }

    @Published var selectedLanguage: String {
        didSet { UserDefaults.standard.set(selectedLanguage, forKey: "selectedLanguage") }
    }

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        self.token = UserDefaults.standard.string(forKey: "token") ?? ""
        self.householdId = UserDefaults.standard.string(forKey: "householdId") ?? "Family"
        self.shoppingListId = UserDefaults.standard.string(forKey: "shoppingListId") ?? ""
        self.sendOptionalHeaders = UserDefaults.standard.bool(forKey: "sendOptionalHeaders")
        self.optionalHeaderKey1 = UserDefaults.standard.string(forKey: "optionalHeaderKey1") ?? ""
        self.optionalHeaderValue1 = UserDefaults.standard.string(forKey: "optionalHeaderValue1") ?? ""
        self.optionalHeaderKey2 = UserDefaults.standard.string(forKey: "optionalHeaderKey2") ?? ""
        self.optionalHeaderValue2 = UserDefaults.standard.string(forKey: "optionalHeaderValue2") ?? ""
        self.optionalHeaderKey3 = UserDefaults.standard.string(forKey: "optionalHeaderKey3") ?? ""
        self.optionalHeaderValue3 = UserDefaults.standard.string(forKey: "optionalHeaderValue3") ?? ""
        self.selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? Locale.current.language.languageCode?.identifier ?? "de"
    }

    var isConfigured: Bool {
        !serverURL.isEmpty && !token.isEmpty && !householdId.isEmpty && !shoppingListId.isEmpty
    }
}

// MARK: - API Konfiguration

extension AppSettings {
    func configureAPIService() {
        var headers: [String: String] = [:]

        if sendOptionalHeaders {
            let rawHeaders = [
                optionalHeaderKey1: optionalHeaderValue1,
                optionalHeaderKey2: optionalHeaderValue2,
                optionalHeaderKey3: optionalHeaderValue3
            ]

            headers = Dictionary(uniqueKeysWithValues: rawHeaders.compactMap { key, value in
                let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return (!trimmedKey.isEmpty && !trimmedValue.isEmpty) ? (trimmedKey, trimmedValue) : nil
            })
        }

        if let url = URL(string: serverURL) {
            APIService.shared.configure(baseURL: url, token: token, optionalHeaders: headers)
            print("✅ API konfiguriert mit \(url), optionale Header: \(headers)")
        }
    }
}
