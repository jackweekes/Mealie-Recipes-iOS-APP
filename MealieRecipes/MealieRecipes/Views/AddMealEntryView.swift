import SwiftUI

struct AddMealEntryView: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (_ date: Date, _ slot: String, _ recipeId: String?, _ note: String?) -> Void

    @State private var selectedDate = Date()
    @State private var selectedSlot: String = "lunch"
    @State private var recipes: [RecipeSummary] = []
    @State private var isLoading = false
    @State private var searchText: String = ""

    var filteredRecipes: [RecipeSummary] {
        if searchText.isEmpty {
            return recipes
        } else {
            return recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Datumsauswahl
                DatePicker(LocalizedStringProvider.localized("select_date"), selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)

                // Slot-Auswahl
                Picker(LocalizedStringProvider.localized("select_slot"), selection: $selectedSlot) {
                    Text("🍳 \(LocalizedStringProvider.localized("breakfast"))").tag("breakfast")
                    Text("🥪 \(LocalizedStringProvider.localized("lunch"))").tag("lunch")
                    Text("🍽 \(LocalizedStringProvider.localized("dinner"))").tag("dinner")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Rezeptliste & manuelle Eingabe
                if isLoading {
                    ProgressView(LocalizedStringProvider.localized("loading_recipes"))
                        .padding()
                } else {
                    List {
                        ForEach(filteredRecipes) { recipe in
                            Button {
                                onAdd(selectedDate, selectedSlot, recipe.id, nil)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(recipe.name)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }

                        // Freitextoption, falls kein Rezept gefunden wurde
                        if !searchText.isEmpty && filteredRecipes.isEmpty {
                            Section {
                                Button {
                                    onAdd(selectedDate, selectedSlot, nil, searchText)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text("➕ \(LocalizedStringProvider.localized("add_custom_meal")) \"\(searchText)\"")
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: LocalizedStringProvider.localized("search_recipes"))
                }
            }
            .navigationTitle(LocalizedStringProvider.localized("plan_meal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringProvider.localized("cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRecipes()
            }
        }
    }

    func loadRecipes() {
        Task {
            isLoading = true
            do {
                recipes = try await APIService.shared.fetchRecipes()
            } catch {
                print("❌ Fehler beim Laden der Rezepte: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
}
