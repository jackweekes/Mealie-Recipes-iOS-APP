import Foundation
import SwiftUI

@MainActor
class MealplanViewModel: ObservableObject {
    @Published var entriesByDay: [Date: [MealplanEntry]] = [:]
    @Published var isLoading = false

    init() {
        fetchMealplan()
    }

    func fetchMealplan() {
        Task {
            await fetchMealplanAsync()
        }
    }

    func fetchMealplanAsync() async {
        isLoading = true
        do {
            let entries = try await APIService.shared.fetchMealplanEntries()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let grouped = Dictionary(grouping: entries, by: { entry in
                formatter.date(from: entry.date) ?? Date.distantPast
            })
            entriesByDay = grouped
        } catch {
            print("❌ Fehler beim Laden des Mealplans: \(error.localizedDescription)")
            entriesByDay = [:]
        }
        isLoading = false
    }

    func refresh() {
        fetchMealplan()
    }

    func localizedDate(_ date: Date) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: AppSettings.shared.selectedLanguage)
        displayFormatter.dateFormat = "EEEE, d. MMMM yyyy"
        return displayFormatter.string(from: date)
    }

    func addMeal(date: Date, recipeId: String?, slot: String, note: String?) {
        Task {
            do {
                try await APIService.shared.addMealEntry(
                    date: date,
                    slot: slot,
                    recipeId: recipeId,
                    note: note
                )
                await fetchMealplanAsync()
            } catch {
                print("❌ Fehler beim Einplanen: \(error.localizedDescription)")
            }
        }
    }

    func recipeImageURL(for imageId: String) -> URL? {
        guard let base = APIService.shared.getBaseURL() else { return nil }
        return base.appendingPathComponent("api/media/recipes/\(imageId)")
    }

    func removeMeal(_ entry: MealplanEntry) {
        Task {
            do {
                try await APIService.shared.deleteMealEntry(entry.id)
                await fetchMealplanAsync()
            } catch {
                print("❌ Fehler beim Entfernen der Mahlzeit: \(error.localizedDescription)")
            }
        }
    }
}
