import SwiftUI

struct RecipeListView: View {
    @StateObject private var viewModel = RecipeListViewModel()
    let settings = AppSettings.shared
    @State private var searchText = ""
    @State private var selectedTag: Tag?

    var allTags: [Tag] {
        let all = viewModel.recipes.flatMap { $0.tags }
        let unique = Dictionary(grouping: all, by: { $0.id }).compactMap { $0.value.first }
        return unique.sorted(by: { $0.name < $1.name })
    }

    var filteredRecipes: [RecipeSummary] {
        viewModel.recipes.filter { recipe in
            let matchesSearch = searchText.isEmpty ||
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.tags.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })

            let matchesTag = selectedTag == nil ||
                recipe.tags.contains(where: { $0.id == selectedTag?.id })

            return matchesSearch && matchesTag
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: {
                                selectedTag = nil
                            }) {
                                Text(LocalizedStringProvider.localized("all"))
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedTag == nil ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                                    .cornerRadius(6)
                            }

                            ForEach(allTags, id: \.id) { tag in
                                Button(action: {
                                    selectedTag = tag
                                }) {
                                    Text(tag.name)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(selectedTag?.id == tag.id ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if viewModel.isLoading {
                    ProgressView(LocalizedStringProvider.localized("loading_recipes"))
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(String(format: LocalizedStringProvider.localized("error_loading_recipes"), errorMessage))
                        .foregroundColor(.red)
                } else {
                    ForEach(filteredRecipes) { recipe in
                        if let uuid = UUID(uuidString: recipe.id) {
                            NavigationLink(destination: RecipeDetailView(recipeId: uuid)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(recipe.name)
                                        .font(.headline)

                                    if !recipe.tags.isEmpty {
                                        HStack {
                                            ForEach(recipe.tags, id: \.id) { tag in
                                                Text(tag.name)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.gray.opacity(0.2))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
                            Text(LocalizedStringProvider.localized("invalid_recipe_id"))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: Text(LocalizedStringProvider.localized("search_recipe")))
            .navigationTitle(LocalizedStringProvider.localized("recipes"))
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
