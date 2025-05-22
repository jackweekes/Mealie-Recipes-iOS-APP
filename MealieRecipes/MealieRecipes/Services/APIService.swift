import Foundation
import UIKit

class APIService {
    static let shared = APIService()

    private var baseURL: URL?
    private var token: String?
    private var optionalHeaders: [String: String] = [:]

    var getOptionalHeaders: [String: String] {
        optionalHeaders
    }

    private init() {}

    func configure(baseURL: URL, token: String, optionalHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.token = token
        let cleanedHeaders = optionalHeaders.filter { !$0.key.isEmpty && !$0.value.isEmpty }

        if let host = baseURL.host,
           !(host.hasPrefix("192.168.") || host.hasPrefix("10.") || host.hasPrefix("127.") || host.hasPrefix("172.")) {
            self.optionalHeaders = cleanedHeaders
        } else {
            self.optionalHeaders = [:]
        }
    }

    func getBaseURL() -> URL? { baseURL }
    func getToken() -> String? { token }

    func createRequest(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let baseURL, let token else {
            throw NSError(domain: "API", code: 0, userInfo: [
                NSLocalizedDescriptionKey: LocalizedStringProvider.localized("error_missing_base_url")
            ])
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        for (key, value) in optionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = body
        return request
    }

    // MARK: - Rezepte

    func fetchRecipes() async throws -> [RecipeSummary] {
        let request = try createRequest(path: "api/recipes")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct RecipesResponse: Decodable { let items: [RecipeSummary] }
        return try JSONDecoder().decode(RecipesResponse.self, from: data).items
    }
    
    func fetchAllRecipeDetails() async throws -> [RecipeDetail] {
        let summaries = try await fetchRecipes() // liefert [RecipeSummary]
        var allDetails: [RecipeDetail] = []

        for summary in summaries {
            let detail = try await fetchRecipeDetail(id: summary.id) // ✅ .id ist String!
            allDetails.append(detail)
        }

        return allDetails
    }


    func fetchRecipeDetail(id: String) async throws -> RecipeDetail {
        let request = try createRequest(path: "api/recipes/\(id)")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(RecipeDetail.self, from: data)
    }

    func uploadRecipeStruct(_ recipe: RecipeCreatePayload) async throws {
        let body = try JSONEncoder().encode(recipe)
        let request = try createRequest(path: "api/recipes/", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }

        print("📤 POST /api/recipes Status: \(httpResponse.statusCode)")
        print("📦 Antwort: \(String(data: data, encoding: .utf8) ?? "(leer)")")
    }

    func deleteRecipe(recipeId: UUID) async throws {
        let request = try createRequest(path: "api/recipes/\(recipeId.uuidString)", method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Rezept-Upload via JSON, URL, Bild

    func uploadRecipeJSON(_ json: String) async throws {
        let escaped = json.replacingOccurrences(of: "\"", with: "\\\"")
        let payload = "{ \"data\": \"\(escaped)\" }"
        
        guard let body = payload.data(using: .utf8) else {
            throw NSError(domain: "UploadError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: LocalizedStringProvider.localized("error_payload_encoding")
            ])
        }

        let request = try createRequest(path: "api/recipes/create/html-or-json", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "UploadError", code: status, userInfo: [
                NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Fehler"
            ])
        }
    }


    func uploadRecipeFromJSON(_ recipe: [String: Any]) async throws {
        let jsonData = try JSONSerialization.data(withJSONObject: recipe)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        try await uploadRecipeJSON(jsonString)
    }

    func uploadRecipeFromURL(url: String) async throws -> String {
        let body = try JSONEncoder().encode(["url": url])
        let request = try createRequest(path: "api/recipes/create/url", method: "POST", body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\""))) ?? ""
    }

    func uploadRecipeImage(_ image: UIImage, translateLanguage: String = "de-DE") async throws -> String {
        guard let baseURL, let token else { throw URLError(.badURL) }

        let url = baseURL.appendingPathComponent("api/recipes/create/image")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "translateLanguage", value: translateLanguage)]

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
                NSLocalizedDescriptionKey: LocalizedStringProvider.localized("error_image_conversion")
            ])
        }

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"images\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\""))) ?? ""
    }

    // MARK: - Einkaufslisten

    func fetchShoppingListItems() async throws -> [ShoppingItem] {
        let request = try createRequest(path: "api/households/shopping/items")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Response: Decodable { let items: [ShoppingItem] }
        return try JSONDecoder().decode(Response.self, from: data).items
    }

    func addShoppingItem(note: String, labelId: String?) async throws -> ShoppingItem {
        struct Payload: Encodable {
            let note: String
            let shoppingListId: String
            let labelId: String?
        }

        let payload = Payload(note: note, shoppingListId: AppSettings.shared.shoppingListId, labelId: labelId)
        let body = try JSONEncoder().encode(payload)
        let request = try createRequest(path: "api/households/shopping/items", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "(keine Antwort)"
            throw NSError(domain: "Shopping", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [
                NSLocalizedDescriptionKey: "Serverfehler beim Hinzufügen: \(message)"
            ])
        }

        return try JSONDecoder().decode(ShoppingItem.self, from: data)
    }



    func updateShoppingItem(_ item: ShoppingItem) async throws {
        struct Payload: Codable {
            let id: UUID
            let note: String
            let shoppingListId: String
            let checked: Bool
            let labelId: String?
            let quantity: Double?
        }

        let payload = Payload(
            id: item.id,
            note: item.note ?? "",
            shoppingListId: item.shoppingListId,
            checked: item.checked,
            labelId: item.label?.id,
            quantity: item.quantity
        )

        let body = try JSONEncoder().encode(payload)
        let request = try createRequest(path: "api/households/shopping/items/\(item.id.uuidString)", method: "PUT", body: body)
        _ = try await URLSession.shared.data(for: request)
    }

    func deleteShoppingItem(id: UUID) async throws {
        let request = try createRequest(path: "api/households/shopping/items/\(id.uuidString)", method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }

    func deleteShoppingItems(_ items: [ShoppingItem]) async {
        for item in items where item.checked {
            do {
                try await deleteShoppingItem(id: item.id)
            } catch {
                print("❌ Fehler beim Löschen: \(error.localizedDescription)")
            }
        }
    }

    func fetchShoppingLabels() async throws -> [ShoppingItem.LabelWrapper] {
        let request = try createRequest(path: "api/groups/labels")
        let (data, _) = try await URLSession.shared.data(for: request)

        struct LabelResponse: Decodable {
            let id: String
            let name: String
            let color: String
        }

        struct PageResponse: Decodable {
            let items: [LabelResponse]
        }

        let decoded = try JSONDecoder().decode(PageResponse.self, from: data)
        return decoded.items.map { ShoppingItem.LabelWrapper(id: $0.id, name: $0.name, color: $0.color) }
    }

    func fetchShoppingLists() async throws -> [ShoppingList] {
        let request = try createRequest(path: "api/households/shopping/lists")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ShoppingListResponse.self, from: data).items
    }

    // MARK: - Mealplan

    func fetchMealplanEntries() async throws -> [MealplanEntry] {
        let request = try createRequest(path: "api/households/mealplans")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Response: Decodable { let items: [MealplanEntry] }
        return try JSONDecoder().decode(Response.self, from: data).items
    }

    func addMealEntry(date: Date, slot: String, recipeId: String?, note: String?) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        struct Payload: Codable {
            let date: String
            let entryType: String
            let recipeId: String?
            let title: String?
        }

        let payload = Payload(
            date: formatter.string(from: date),
            entryType: slot,
            recipeId: recipeId,
            title: recipeId == nil ? note : nil
        )

        let body = try JSONEncoder().encode(payload)
        let request = try createRequest(path: "api/households/mealplans", method: "POST", body: body)
        _ = try await URLSession.shared.data(for: request)
    }

    func deleteMealEntry(_ entryId: Int) async throws {
        let request = try createRequest(path: "api/households/mealplans/\(entryId)", method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Multipart-Erweiterung

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
