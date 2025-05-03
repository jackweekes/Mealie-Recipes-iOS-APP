import Foundation

@MainActor
class ShoppingListViewModel: ObservableObject {
    @Published var shoppingList: [ShoppingItem] = []
    @Published var archivedLists: [[ShoppingItem]] = []

    init() {
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
                print("❌ Fehler beim Synchronisieren des Status in Mealie: \(error)")
                updated.checked.toggle()
                shoppingList[index] = updated
            }
        }
    }


    func deleteIngredient(at offsets: IndexSet) {
        for index in offsets {
            let item = shoppingList[index]
            Task {
                try? await APIService.shared.deleteShoppingItem(id: item.id)
            }
        }
        shoppingList.remove(atOffsets: offsets)
    }

    func addManualIngredient(note: String) {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else { return }

        let cleaned = cleanedNote(from: trimmedNote)
        guard !cleaned.isEmpty else { return }

        // Optional: Lokal prüfen, ob es den Eintrag schon gibt
        if shoppingList.contains(where: { $0.note?.lowercased() == cleaned.lowercased() }) {
            print("⚠️ '\(cleaned)' ist bereits in der Liste.")
            return
        }

        Task {
            do {
                // 1. Artikel an Mealie senden
                _ = try await APIService.shared.addShoppingItem(note: cleaned)

                // 2. Kurze Pause, um Serververarbeitung zu ermöglichen (optional)
                try? await Task.sleep(nanoseconds: 250_000_000)

                // 3. Liste vollständig neu vom Server laden
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

                // Dubletten vermeiden
                if !shoppingList.contains(where: { $0.note?.lowercased() == note.lowercased() }) {
                    do {
                        _ = try await APIService.shared.addShoppingItem(note: note)
                        newNotes.append(note)
                    } catch {
                        print("❌ Fehler beim Hinzufügen von '\(note)': \(error)")
                    }
                } else {
                    print("⚠️ '\(note)' ist bereits auf der Liste.")
                }
            }

            // Wenn neue Artikel hinzugefügt wurden, dann vom Server neu laden
            if !newNotes.isEmpty {
                try? await Task.sleep(nanoseconds: 250_000_000)
                do {
                    let updatedItems = try await APIService.shared.fetchShoppingListItems()
                    self.shoppingList = updatedItems
                } catch {
                    print("❌ Fehler beim Neuladen der Liste: \(error)")
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
        } catch {
            print("❌ Fehler beim Laden der Einkaufsliste von Mealie: \(error)")
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
