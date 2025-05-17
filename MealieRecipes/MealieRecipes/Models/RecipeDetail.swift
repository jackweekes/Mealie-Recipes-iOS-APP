import Foundation

struct RecipeDetail: Identifiable, Codable {
    let id: String
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
        case tags
    }
}

extension RecipeDetail {
    func hasAllMatchingIngredients(_ inputNames: [String]) -> Bool {
        let lowercasedInput = inputNames.map { $0.lowercased() }
        return lowercasedInput.allSatisfy { input in
            ingredients.contains {
                $0.note?.lowercased().contains(input) == true
            }
        }
    }


    func matchingIngredientCount(haveIngredients: [String]) -> Int {
        let lowercasedInput = haveIngredients.map { $0.lowercased() }
        return ingredients.filter { ingredient in
            lowercasedInput.contains { input in
                ingredient.note?.lowercased().contains(input) == true
            }
        }.count
    }

    func matchingIngredientPercentage(haveIngredients: [String]) -> Double {
        let total = max(1, ingredients.count) // verhindert Division durch 0
        let count = matchingIngredientCount(haveIngredients: haveIngredients)
        return Double(count) / Double(total) * 100
    }

}

struct Ingredient: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var note: String?
    var quantity: Double?
    var unit: String?
    var isCompleted: Bool = false

    enum CodingKeys: String, CodingKey {
        case note, quantity, unit
    }
}

struct Instruction: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String

    enum CodingKeys: String, CodingKey {
        case text
    }
}

struct RecipeTag: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var slug: String
}

