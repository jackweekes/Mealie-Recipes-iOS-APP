import Foundation

@MainActor
class ShoppingListViewModel: ObservableObject {
    @Published var shoppingList: [ShoppingItem] = []
    @Published var archivedLists: [[ShoppingItem]] = []
    @Published var availableLabels: [ShoppingItem.LabelWrapper] = []
    @Published var availableShoppingLists: [ShoppingList] = []
    @Published var isConnectedToAPI: Bool = true


    init() {
        print("🛒 ShoppingListViewModel initialisiert")
        Task {
            await loadShoppingListFromServer()
            await loadLabels()
        }
    }

    // MARK: - Aktionen

    func toggleIngredientCompletion(_ item: ShoppingItem) {
        Task {
            var updatedItem = item
            updatedItem.checked.toggle()

            do {
                try await APIService.shared.updateShoppingItem(updatedItem)
                if let index = shoppingList.firstIndex(where: { $0.id == item.id }) {
                    shoppingList[index] = updatedItem
                    self.isConnectedToAPI = true
                }
            } catch {
                print("❌ Fehler beim Update: \(error.localizedDescription)")
                self.isConnectedToAPI = false
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
    
    
    func addManualIngredient(note: String, label: ShoppingItem.LabelWrapper?) async {
        do {
            var item = try await APIService.shared.addShoppingItem(note: note, labelId: label?.id)
            item.label = label
            shoppingList.append(item)
            print("🛒 Added item, total count now: \(shoppingList.count)")
            self.isConnectedToAPI = true
        } catch {
            print("❌ Fehler beim Hinzufügen: \(error)")
            self.isConnectedToAPI = false
            
        }
    }

    
    func loadLabels() async {
        do {
            let labels = try await APIService.shared.fetchShoppingLabels()
            self.availableLabels = labels
        } catch {
            print("❌ Fehler beim Laden der Labels: \(error.localizedDescription)")
            
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
                        _ = try await APIService.shared.addShoppingItem(note: note, labelId: nil)
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
  
    func fetchAvailableShoppingLists() async {
        do {
            let lists = try await APIService.shared.fetchShoppingLists()
            DispatchQueue.main.async {
                self.availableShoppingLists = lists
            }
        } catch {
            print("❌ Fehler beim Laden der Einkaufsliste(n): \(error.localizedDescription)")
           
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
    
    func updateIngredient(item: ShoppingItem, newNote: String, newLabel: ShoppingItem.LabelWrapper?, newQuantity: Double?) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }

        shoppingList[index].note = newNote
        shoppingList[index].label = newLabel
        shoppingList[index].quantity = newQuantity

        Task {
            await updateIngredientOnServer(item: shoppingList[index])
        }
    }

    // MARK: - Mealie Sync
    @MainActor
    func loadShoppingListFromServer() async {
        do {
            let items = try await APIService.shared.fetchShoppingListItems()
            self.shoppingList = items
            // pulling the labels from a seperate API call instead so they all show
            //self.availableLabels = extractLabelsFromItems(items)
            print("✅ Einkaufsliste geladen: \(items.count) Einträge")
            self.isConnectedToAPI = true
        } catch {
            print("❌ Fehler beim Laden der Einkaufsliste von Mealie: \(error.localizedDescription)")
            self.isConnectedToAPI = false
        }
    }

    var uncheckedItemCount: Int {
        shoppingList.filter { !$0.checked }.count
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
/*
private func extractLabelsFromItems(_ items: [ShoppingItem]) -> [ShoppingItem.LabelWrapper] {
    let labels = items.compactMap { $0.label }
    let unique = Array(Set(labels)) 
    return unique.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
}*/

private func updateIngredientOnServer(item: ShoppingItem) async {
    do {
        try await APIService.shared.updateShoppingItem(item)
    } catch {
        print("❌ Fehler beim Synchronisieren mit dem Server: \(error.localizedDescription)")
    }
}
