import SwiftUI
import UIKit

struct RecipeDetailView: View {
    let recipeId: UUID
    @StateObject private var viewModel = RecipeDetailViewModel()
    @StateObject private var timerModel = TimerViewModel()

    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dismiss) var dismiss

    @State private var showIngredients = false
    @State private var showInstructions = false
    @State private var showSuccessAlert = false
    @State private var showTimerSheet = false
    @State private var showDeleteConfirmation = false
    @State private var timerDurationMinutes: Double = 1
    @State private var completedIngredients: Set<UUID> = []
    @State private var completedInstructions: Set<UUID> = []
    @State private var keepScreenOn = false
    @State private var quantityMultiplier: Double = 1.0

    var body: some View {
        Group {
            if let recipe = viewModel.recipe {
                content(for: recipe)
            } else if viewModel.isLoading {
                ProgressView(LocalizedStringProvider.localized("loading_recipe"))
            } else {
                Text(LocalizedStringProvider.localized("error_loading_recipe"))
                    .foregroundColor(.red)
            }
        }
        .navigationTitle(LocalizedStringProvider.localized("details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }

        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(LocalizedStringProvider.localized("confirm_delete_title")),
                message: Text(LocalizedStringProvider.localized("confirm_delete_message")),
                primaryButton: .destructive(Text(LocalizedStringProvider.localized("delete"))) {
                    Task {
                        await deleteRecipe()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            viewModel.fetchRecipe(by: recipeId.uuidString)
            resetCompleted()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    @ViewBuilder
    private func content(for recipe: RecipeDetail) -> some View {
        if UIDevice.current.orientation.isLandscape {
            HStack(alignment: .top) {
                sideBar(for: recipe)
                ScrollView {
                    recipeContent(recipe)
                }.padding()
            }
        } else {
            ScrollView {
                recipeContent(recipe).padding()
            }
        }
    }

    @ViewBuilder
    private func sideBar(for recipe: RecipeDetail) -> some View {
        VStack {
            if let url = buildImageURL(recipeID: recipe.id),
               let token = APIService.shared.getToken() {
                AuthenticatedAsyncImage(url: url, token: token)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text(recipe.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.top)
        }
        .frame(width: 240)
        .padding()
    }

    @ViewBuilder
    private func recipeContent(_ recipe: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let desc = recipe.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ingredientButtons()
            ingredientGroup(recipe)
            timerButton()
            instructionGroup(recipe)

            Toggle(LocalizedStringProvider.localized("display_always_on"), isOn: $keepScreenOn)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .onChange(of: keepScreenOn) {
                    UIApplication.shared.isIdleTimerDisabled = $0
                }

           
            if !recipe.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringProvider.localized("tags"))
                        .font(.headline)
                    WrapHStack(tags: recipe.tags.map { $0.name })
                }
            }

        }
    }

    private func ingredientButtons() -> some View {
        Menu {
            Button(LocalizedStringProvider.localized("add_all_ingredients")) {
                addIngredientsToShoppingList(onlyCompleted: false)
            }
            Button(LocalizedStringProvider.localized("add_selected_ingredients")) {
                addIngredientsToShoppingList(onlyCompleted: true)
            }
        } label: {
            Label(LocalizedStringProvider.localized("ingredients"), systemImage: "cart.badge.plus")
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text(LocalizedStringProvider.localized("add_ingredients_title")),
                message: Text(LocalizedStringProvider.localized("add_ingredients_message")),
                dismissButton: .default(Text(LocalizedStringProvider.localized("ok")))
            )
        }
    }

    private func ingredientGroup(_ recipe: RecipeDetail) -> some View {
        customDisclosureGroup(
            title: LocalizedStringProvider.localized("ingredients"),
            systemImage: "list.bullet",
            isExpanded: $showIngredients
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringProvider.localized("adjust_quantity"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ForEach([0.5, 1.0, 1.5, 2.0, 2.5, 3.0], id: \.self) { factor in
                        Button(action: {
                            quantityMultiplier = factor
                        }) {
                            Text(factor == floor(factor) ? "\(Int(factor))×" : String(format: "%.1f×", factor))
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(quantityMultiplier == factor ? Color.accentColor : Color(.systemGray5))
                                .foregroundColor(quantityMultiplier == factor ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recipe.ingredients) { ingredient in
                        Button(action: {
                            toggleIngredient(ingredient)
                        }) {
                            HStack {
                                Text(scaledNote(for: ingredient.note))
                                    .font(.body)
                                Spacer()
                                if completedIngredients.contains(ingredient.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(8)
                            .background(completedIngredients.contains(ingredient.id) ? Color.green.opacity(0.2) : Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func timerButton() -> some View {
        Button(action: {
            showTimerSheet = true
        }) {
            Label(timerButtonLabel, systemImage: "timer")
                .padding()
                .frame(maxWidth: .infinity)
                .background(timerModel.timerActive ? Color.green : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .sheet(isPresented: $showTimerSheet) {
            TimerView(viewModel: timerModel, durationMinutes: $timerDurationMinutes)
        }
    }

    private func instructionGroup(_ recipe: RecipeDetail) -> some View {
        customDisclosureGroup(
            title: LocalizedStringProvider.localized("instructions"),
            systemImage: "book",
            isExpanded: $showInstructions
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(recipe.instructions) { instruction in
                    Button(action: {
                        toggleInstruction(instruction)
                    }) {
                        HStack {
                            Text("• \(instruction.text)")
                                .font(.body)
                            Spacer()
                            if completedInstructions.contains(instruction.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(8)
                        .background(completedInstructions.contains(instruction.id) ? Color.green.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 8)
        }
    }

    private var timerButtonLabel: String {
        if timerModel.timerActive {
            let minutes = Int(timerModel.timeRemaining) / 60
            let seconds = Int(timerModel.timeRemaining) % 60
            return String(format: LocalizedStringProvider.localized("running_timer"), minutes, seconds)
        } else {
            return LocalizedStringProvider.localized("start_timer")
        }
    }

    private func buildImageURL(recipeID: String) -> URL? {
        guard let base = APIService.shared.getBaseURL() else { return nil }
        return base
            .appendingPathComponent("api/media/recipes")
            .appendingPathComponent(recipeID)
            .appendingPathComponent("images/original.webp")
    }

    private func resetCompleted() {
        completedIngredients = []
        completedInstructions = []
    }

    private func addIngredientsToShoppingList(onlyCompleted: Bool) {
        guard let recipe = viewModel.recipe else { return }
        let toAdd = onlyCompleted
            ? recipe.ingredients.filter { completedIngredients.contains($0.id) }
            : recipe.ingredients
        shoppingListViewModel.addIngredients(toAdd)
        showSuccessAlert = true
    }

    private func toggleIngredient(_ ingredient: Ingredient) {
        if completedIngredients.contains(ingredient.id) {
            completedIngredients.remove(ingredient.id)
        } else {
            completedIngredients.insert(ingredient.id)
        }
    }

    private func toggleInstruction(_ instruction: Instruction) {
        if completedInstructions.contains(instruction.id) {
            completedInstructions.remove(instruction.id)
        } else {
            completedInstructions.insert(instruction.id)
        }
    }

    private func scaledNote(for note: String?) -> String {
        guard let note = note else { return "-" }
        let pattern = "^([\\d.,/]+)(\\s?[a-zA-Z]*)?(.*)$"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: note, range: NSRange(note.startIndex..., in: note)) {
            let numberRange = Range(match.range(at: 1), in: note)
            let unitRange = Range(match.range(at: 2), in: note)
            let restRange = Range(match.range(at: 3), in: note)

            if let numberStr = numberRange.map({ String(note[$0]) }) {
                let parsedNumber: Double? = {
                    if numberStr.contains("/") {
                        let parts = numberStr.split(separator: "/").compactMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
                        return parts.count == 2 ? parts[0] / parts[1] : nil
                    } else {
                        return Double(numberStr.replacingOccurrences(of: ",", with: "."))
                    }
                }()

                if let amount = parsedNumber {
                    let newAmount = amount * quantityMultiplier
                    let unit = unitRange.map { String(note[$0]).trimmingCharacters(in: .whitespaces) } ?? ""
                    let rest = restRange.map { String(note[$0]) } ?? ""
                    let formatted = newAmount == floor(newAmount) ? "\(Int(newAmount))" : String(format: "%.2f", newAmount)
                    return "\(formatted) \(unit)\(rest)"
                }
            }
        }
        return note
    }

    private func customDisclosureGroup<Content: View>(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation { isExpanded.wrappedValue.toggle() }
            }) {
                HStack {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .foregroundColor(.accentColor)
                        .imageScale(.small)
                    Label(title, systemImage: systemImage)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }

            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity)
                    .padding(.top, 8)
            }
        }
    }

    private func deleteRecipe() async {
        do {
            try await APIService.shared.deleteRecipe(recipeId: recipeId)
            dismiss()
        } catch {
            print("Fehler beim Löschen: \(error.localizedDescription)")
        }
    }
}

struct AuthenticatedAsyncImage: View {
    let url: URL
    let token: String

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        switch phase {
        case .empty:
            ProgressView().task { await load() }
        case .success(let image):
            image.resizable().scaledToFill()
        case .failure:
            Image(systemName: "photo")
                .resizable().scaledToFit()
                .foregroundColor(.gray)
        @unknown default:
            EmptyView()
        }
    }

    @MainActor
    private func load() async {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let host = APIService.shared.getBaseURL()?.host,
           !host.hasPrefix("192.168."),
           !host.hasPrefix("10."),
           !host.hasPrefix("127."),
           !host.hasPrefix("172.") {
            for (key, value) in APIService.shared.getOptionalHeaders where !key.isEmpty && !value.isEmpty {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let uiImage = UIImage(data: data) else {
                phase = .failure(URLError(.badServerResponse))
                return
            }
            phase = .success(Image(uiImage: uiImage))
        } catch {
            phase = .failure(error)
        }
    }
}

struct WrapHStack: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
        }
    }
}
