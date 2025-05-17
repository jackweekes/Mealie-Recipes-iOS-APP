import SwiftUI
import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private init() {
        // Initialisiere published-Property aus UserDefaults
        self.selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage")
            ?? Locale.current.language.languageCode?.identifier ?? "de"
    }

    //  Nur Sprachwechsel ist für SwiftUI relevant → deshalb @Published
    @Published var selectedLanguage: String {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "selectedLanguage")
        }
    }

    var serverURL: String {
        get { UserDefaults.standard.string(forKey: "serverURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "serverURL") }
    }

    var token: String {
        get { UserDefaults.standard.string(forKey: "token") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "token") }
    }

    var householdId: String {
        get { UserDefaults.standard.string(forKey: "householdId") ?? "Family" }
        set { UserDefaults.standard.set(newValue, forKey: "householdId") }
    }

    var shoppingListId: String {
        get { UserDefaults.standard.string(forKey: "shoppingListId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "shoppingListId") }
    }

    var sendOptionalHeaders: Bool {
        get { UserDefaults.standard.bool(forKey: "sendOptionalHeaders") }
        set { UserDefaults.standard.set(newValue, forKey: "sendOptionalHeaders") }
    }

    var optionalHeaderKey1: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderKey1") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "optionalHeaderKey1") }
    }

    var optionalHeaderValue1: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderValue1") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "optionalHeaderValue1") }
    }

    var optionalHeaderKey2: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderKey2") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "optionalHeaderKey2") }
    }

    var optionalHeaderValue2: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderValue2") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "optionalHeaderValue2") }
    }

    var optionalHeaderKey3: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderKey3") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "optionalHeaderKey3") }
    }

    var optionalHeaderValue3: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderValue3") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "optionalHeaderValue3") }
    }

    var isConfigured: Bool {
        !serverURL.isEmpty && !token.isEmpty && !householdId.isEmpty && !shoppingListId.isEmpty
    }
    
    @Published var showCompleteShoppingButton: Bool = true
}



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
