struct Tag: Codable, Hashable {
    let id: String
    let name: String
    let slug: String
}

struct RecipeSummary: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let tags: [Tag]
}
