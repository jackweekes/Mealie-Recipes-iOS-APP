import Foundation

@MainActor
class ShoppingListViewModel: ObservableObject {
    @Published var shoppingList: [ShoppingItem] = []
    @Published var archivedLists: [[ShoppingItem]] = []

    init() {
        print("🛒 ShoppingListViewModel initialisiert")
        Task {
            await loadShoppingListFromServer()
        }
    }

    // MARK: - Aktionen

    func toggleIngredientCompletion(_ item: ShoppingItem) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }

        var updated = item
        updated.checked.toggle()
        shoppingList[index] = updated

        Task {
            do {
                try await APIService.shared.updateShoppingItem(updated)
            } catch {
                print("❌ Fehler beim Synchronisieren des Status in Mealie: \(error.localizedDescription)")
                updated.checked.toggle()
                shoppingList[index] = updated
            }
        }
    }

    func deleteIngredient(at offsets: IndexSet) {
        for index in offsets {
            let item = shoppingList[index]
            Task {
                do {
                    try await APIService.shared.deleteShoppingItem(id: item.id)
                } catch {
                    print("❌ Fehler beim Löschen eines Elements: \(error.localizedDescription)")
                }
            }
        }
        shoppingList.remove(atOffsets: offsets)
    }

    func addManualIngredient(note: String) {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else { return }

        let cleaned = cleanedNote(from: trimmedNote)
        guard !cleaned.isEmpty else { return }

        if shoppingList.contains(where: { $0.note?.lowercased() == cleaned.lowercased() }) {
            print("⚠️ '\(cleaned)' ist bereits in der Liste.")
            return
        }

        Task {
            do {
                _ = try await APIService.shared.addShoppingItem(note: cleaned)

                try? await Task.sleep(nanoseconds: 250_000_000)

                let updatedItems = try await APIService.shared.fetchShoppingListItems()
                self.shoppingList = updatedItems
            } catch {
                print("❌ Fehler beim Hinzufügen/Synchronisieren: \(error.localizedDescription)")
            }
        }
    }

    func addIngredients(_ ingredients: [Ingredient]) {
        Task {
            var newNotes: [String] = []

            for ingredient in ingredients {
                guard let rawNote = ingredient.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawNote.isEmpty else { continue }

                let note = cleanedNote(from: rawNote)
                guard !note.isEmpty else { continue }

                if !shoppingList.contains(where: { $0.note?.lowercased() == note.lowercased() }) {
                    do {
                        _ = try await APIService.shared.addShoppingItem(note: note)
                        newNotes.append(note)
                    } catch {
                        print("❌ Fehler beim Hinzufügen von '\(note)': \(error.localizedDescription)")
                    }
                } else {
                    print("⚠️ '\(note)' ist bereits auf der Liste.")
                }
            }

            if !newNotes.isEmpty {
                try? await Task.sleep(nanoseconds: 250_000_000)
                do {
                    let updatedItems = try await APIService.shared.fetchShoppingListItems()
                    self.shoppingList = updatedItems
                } catch {
                    print("❌ Fehler beim Neuladen der Liste: \(error.localizedDescription)")
                }
            }
        }
    }

    func archiveList() {
        if !shoppingList.isEmpty {
            archivedLists.append(shoppingList)
            let completedItems = shoppingList.filter { $0.checked }
            shoppingList.removeAll()

            Task {
                await APIService.shared.deleteShoppingItems(completedItems)
            }
        }
    }

    func deleteArchivedList(at offsets: IndexSet) {
        archivedLists.remove(atOffsets: offsets)
    }

    func deleteAllArchivedLists() {
        archivedLists = []
    }

    // MARK: - Mealie Sync

    func loadShoppingListFromServer() async {
        do {
            let items = try await APIService.shared.fetchShoppingListItems()
            self.shoppingList = items
            print("✅ Einkaufsliste geladen: \(items.count) Einträge")
        } catch {
            print("❌ Fehler beim Laden der Einkaufsliste von Mealie: \(error.localizedDescription)")
        }
    }

    // MARK: - Mengenbereinigung

    private func cleanedNote(from rawNote: String) -> String {
        let pattern = #"^\d+([.,]\d+)?\s*(g|ml|TL|EL|Stk|Pck\.?|Msp\.?|Tasse|Tassen|Prise|Scheiben?|Stück|Dose|Dosen)?\s+"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(rawNote.startIndex..<rawNote.endIndex, in: rawNote)
            let cleaned = regex.stringByReplacingMatches(in: rawNote, options: [], range: range, withTemplate: "")
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return rawNote
    }
}
