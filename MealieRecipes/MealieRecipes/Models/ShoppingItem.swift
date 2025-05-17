import Foundation

struct ShoppingItem: Identifiable, Codable {
    var id: UUID
    var note: String?
    var checked: Bool
    var shoppingListId: String
    var label: LabelWrapper? 

    // Abgeleitete Kategorie für Gruppierung
    var category: String? {
        label?.name
    }

    enum CodingKeys: String, CodingKey {
        case id
        case note
        case checked
        case shoppingListId
        case label
    }

    struct LabelWrapper: Codable, Hashable {
        let id: String
        let name: String
    }
}
