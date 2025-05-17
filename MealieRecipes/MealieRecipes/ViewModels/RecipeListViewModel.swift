import Foundation

@MainActor
class RecipeListViewModel: ObservableObject {
    @Published var recipes: [RecipeSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil  // <- FEHLTE bei dir!

    private let apiService = APIService.shared

    func fetchRecipes() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetchedRecipes = try await apiService.fetchRecipes()
                self.recipes = fetchedRecipes
                self.isLoading = false
            } catch {
                self.errorMessage = "Fehler beim Laden: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
