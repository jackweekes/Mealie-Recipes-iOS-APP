import Foundation

@MainActor
class RecipeDetailViewModel: ObservableObject {
    @Published var recipe: RecipeDetail?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let apiService = APIService.shared

    func fetchRecipe(by id: String) {
        isLoading = true
        error = nil

        Task {
            do {
                let fetchedRecipe = try await apiService.fetchRecipeDetail(id: id)
                recipe = fetchedRecipe
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
}
