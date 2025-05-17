import SwiftUI

struct LeftoverRecipeFinderView: View {
    @ObservedObject var viewModel: LeftoverRecipeViewModel
    @State private var ingredientTrigger = UUID()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Abstand nach oben und Beschreibung
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer(minLength: 16)

                        Text(LocalizedStringProvider.localized("leftover.description"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Zutaten-Eingabe
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringProvider.localized("leftover.ingredients"))
                            .font(.headline)
                        IngredientInputView(model: viewModel.inputModel)
                    }
                    .padding(.horizontal)

                    // Rezeptvorschläge
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringProvider.localized("leftover.suggestions"))
                            .font(.headline)

                        if viewModel.isLoading {
                            ProgressView()
                        } else if viewModel.filteredRecipes.isEmpty {
                            Text(LocalizedStringProvider.localized("leftover.no_matches"))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.filteredRecipes, id: \.id) { recipe in
                                if let uuid = UUID(uuidString: recipe.id) {
                                    NavigationLink(destination: RecipeDetailView(recipeId: uuid)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(recipe.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)

                                            Text(viewModel.percentageText(for: recipe))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                                        .padding()
                                        .background(Color(.systemBackground))
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    Text("❌ Invalid Recipe ID")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
                .id(ingredientTrigger)
            }
            .navigationTitle(Text(LocalizedStringProvider.localized("leftover.title")))
            .onAppear {
                viewModel.loadRecipes()
            }
            .onReceive(viewModel.$ingredientTrigger) { newValue in
                ingredientTrigger = newValue
            }
        }
    }
}
