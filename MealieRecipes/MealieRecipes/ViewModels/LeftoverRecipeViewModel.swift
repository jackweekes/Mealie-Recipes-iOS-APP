import Foundation
import Combine

@MainActor
class LeftoverRecipeViewModel: ObservableObject {
    @Published var allRecipes: [RecipeDetail] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    let inputModel: IngredientInputModel
    @Published var ingredientTrigger = UUID()

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    init(inputModel: IngredientInputModel = IngredientInputModel()) {
        self.inputModel = inputModel

        inputModel.$enteredIngredients
            .sink { [weak self] _ in
                self?.ingredientTrigger = UUID()
            }
            .store(in: &cancellables)
    }

    var filteredRecipes: [RecipeDetail] {
        let names = inputModel.enteredIngredients.map { $0.name }
        guard !names.isEmpty else { return [] }

        return allRecipes
            .filter { $0.hasAllMatchingIngredients(names) }
            .sorted {
                $0.matchingIngredientPercentage(haveIngredients: names) >
                $1.matchingIngredientPercentage(haveIngredients: names)
            }
    }


    func loadRecipes() {
        isLoading = true
        error = nil

        Task {
            do {
                let recipes = try await apiService.fetchAllRecipeDetails()
                self.allRecipes = recipes
                print("📦 \(recipes.count) Rezepte von API geladen")
            } catch {
                self.error = error
                print("❌ Fehler beim Laden der Rezepte: \(error.localizedDescription)")
            }
            isLoading = false
        }

    }

    func percentageText(for recipe: RecipeDetail) -> String {
        let names = inputModel.enteredIngredients.map { $0.name }
        let matchCount = recipe.matchingIngredientCount(haveIngredients: names)
        let total = recipe.ingredients.count
        let percent = Int(recipe.matchingIngredientPercentage(haveIngredients: names))

        return "\(percent)% passend (\(matchCount)/\(total))"
    }
}
