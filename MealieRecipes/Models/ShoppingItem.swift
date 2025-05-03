import Foundation

struct ShoppingItem: Identifiable, Codable {
    var id: UUID
    var note: String?
    var checked: Bool
    var shoppingListId: String

    enum CodingKeys: String, CodingKey {
        case id
        case note
        case checked
        case shoppingListId
    }
}


