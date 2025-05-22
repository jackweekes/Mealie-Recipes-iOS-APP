import Foundation

struct ShoppingItem: Identifiable, Codable {
    var id: UUID
    var note: String?
    var checked: Bool
    var shoppingListId: String
    var label: LabelWrapper?
    var quantity: Double?  

    var category: String? {
        label?.name
    }

    enum CodingKeys: String, CodingKey {
        case id
        case note
        case checked
        case shoppingListId
        case label
        case quantity 
    }

    struct LabelWrapper: Codable, Hashable {
        let id: String
        let name: String
        let color: String
    }
}
