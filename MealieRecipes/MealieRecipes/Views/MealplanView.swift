import SwiftUI

struct MealplanView: View {
    @StateObject private var viewModel = MealplanViewModel()
    @State private var showAddMealSheet = false
    @State private var currentWeekStart: Date = Self.defaultStartOfWeek()

    var body: some View {
        NavigationStack {
            VStack {
                calendarHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if filteredEntriesByDay.isEmpty {
                            Text(LocalizedStringProvider.localized("no_meals"))
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            let sortedKeys = filteredEntriesByDay.keys.sorted()
                            ForEach(sortedKeys, id: \.self) { date in
                                Section(header: Text(viewModel.localizedDate(date)).font(.headline)) {
                                    ForEach(filteredEntriesByDay[date] ?? []) { entry in
                                        mealEntryRow(entry)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizedStringProvider.localized("meal_plan"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddMealSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddMealSheet) {
                AddMealEntryView { date, slot, recipeId, note in
                    Task {
                        do {
                            try await APIService.shared.addMealEntry(
                                date: date,
                                slot: slot,
                                recipeId: recipeId,
                                note: note
                            )
                            await viewModel.fetchMealplanAsync()
                        } catch {
                            print("❌ Fehler beim Hinzufügen: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    private var calendarHeader: some View {
        HStack {
            Button {
                if let previousWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) {
                    currentWeekStart = Calendar.current.startOfWeek(for: previousWeek)
                }
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(weekHeaderText)
                .font(.headline)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                if let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) {
                    currentWeekStart = Calendar.current.startOfWeek(for: nextWeek)
                }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    var filteredEntriesByDay: [Date: [MealplanEntry]] {
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStart)!
        return viewModel.entriesByDay.filter { date, _ in
            return date >= currentWeekStart && date <= endOfWeek
        }
    }

    var weekHeaderText: String {
        let calendar = Calendar.current
        let weekNumber = currentWeekStart.calendarWeekNumber()
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: currentWeekStart)!

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return "KW \(weekNumber) (\(formatter.string(from: currentWeekStart)) – \(formatter.string(from: endOfWeek)))"
    }

    @ViewBuilder
    func mealEntryRow(_ entry: MealplanEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(slotEmoji(entry.entryType)) \(LocalizedStringProvider.localized(entry.entryType))")
                .font(.subheadline)
                .frame(width: 120, alignment: .leading)

            VStack(alignment: .leading) {
                if let recipe = entry.recipe {
                    if let id = UUID(uuidString: recipe.id) {
                        NavigationLink(destination: RecipeDetailView(recipeId: id)) {
                            Text(recipe.name)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text(recipe.name)
                            .font(.body)
                            .foregroundColor(.red)
                        Text(LocalizedStringProvider.localized("invalid_recipe_id"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let title = entry.title {
                    Text(title)
                        .font(.body)
                        .italic()
                    Text(LocalizedStringProvider.localized("no_recipe_linked"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("🛑 \(LocalizedStringProvider.localized("unknown_entry"))")
                        .foregroundColor(.red)
                }
            }

            Spacer()

            Button(role: .destructive) {
                viewModel.removeMeal(entry)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }

    func slotEmoji(_ slot: String) -> String {
        switch slot.lowercased() {
        case "breakfast": return "🍳"
        case "lunch":     return "🥪"
        case "dinner":    return "🍽"
        default:          return "🍴"
        }
    }

    private static func defaultStartOfWeek() -> Date {
        Calendar.current.startOfWeek(for: Date())
    }
}
