import Foundation

struct RecipeDetail: Identifiable, Codable {
    let id: String            // API liefert ID als String
    let name: String
    let description: String?
    let image: String?
    let ingredients: [Ingredient]
    let instructions: [Instruction]
    let tags: [Tag]


    enum CodingKeys: String, CodingKey {
        case id, name, description, image
        case ingredients = "recipeIngredient"
        case instructions = "recipeInstructions"
        case tags // neu
    }

}

struct Ingredient: Identifiable, Codable, Equatable {
    var id: UUID = UUID()                // Lokale ID für SwiftUI
    var note: String?
    var quantity: Double?
    var unit: String?
    var isCompleted: Bool = false        

    enum CodingKeys: String, CodingKey {
        case note, quantity, unit
        // isCompleted und id sind lokal und werden nicht aus dem JSON gemappt
    }
}

struct Instruction: Identifiable, Codable, Equatable {
    var id: UUID = UUID()      // Lokale feste UUID beim Erstellen
    var text: String

    enum CodingKeys: String, CodingKey {
        case text
    }
}

