import SwiftUI

struct RecipeListView: View {
    @StateObject private var viewModel = RecipeListViewModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var searchText = ""

    var filteredRecipes: [RecipeSummary] {
        if searchText.isEmpty {
            return viewModel.recipes
        } else {
            return viewModel.recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let horizontalPadding = isLandscape ? geometry.size.width * 0.2 : 0.0

                VStack {
                    Spacer()

                    if viewModel.isLoading {
                        ProgressView(LocalizedStringProvider.localized("loading_recipes"))
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(String(format: LocalizedStringProvider.localized("error_loading_recipes"), errorMessage))
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        List(filteredRecipes) { recipe in
                            if let uuid = UUID(uuidString: recipe.id) {
                                NavigationLink(destination: RecipeDetailView(recipeId: uuid)) {
                                    Text(recipe.name)
                                        .font(.headline)
                                }
                            } else {
                                Text(LocalizedStringProvider.localized("invalid_recipe_id"))
                                    .foregroundColor(.red)
                            }
                        }
                        .listStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(LocalizedStringProvider.localized("recipes"))
                .searchable(text: $searchText, prompt: Text(LocalizedStringProvider.localized("search_recipe")))
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                configureAPIIfNeeded()
                viewModel.fetchRecipes()
            }
        }
    }

    private func configureAPIIfNeeded() {
        guard let url = URL(string: settings.serverURL), !settings.token.isEmpty else {
            print("[RecipeListView] Fehler: Ungültige Einstellungen")
            return
        }

        var headers: [String: String] = [:]
        if settings.sendOptionalHeaders {
            headers[settings.optionalHeaderKey1] = settings.optionalHeaderValue1
            headers[settings.optionalHeaderKey2] = settings.optionalHeaderValue2
            headers[settings.optionalHeaderKey3] = settings.optionalHeaderValue3
        }

        APIService.shared.configure(
            baseURL: url,
            token: settings.token,
            optionalHeaders: headers
        )

        print("✅ [RecipeListView] API konfiguriert mit \(url), optionale Header: \(headers)")
    }
}

