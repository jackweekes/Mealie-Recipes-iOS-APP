import SwiftUI
import Combine

struct ShoppingListView: View {
    @EnvironmentObject private var viewModel: ShoppingListViewModel
    @State private var newItemNote: String = ""
    @State private var selectedLabel: ShoppingItem.LabelWrapper?
    @State private var showSuccessToast = false
    @State private var showArchiveAlert = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var collapsedCategories: Set<String> = []
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let horizontalPadding = isLandscape ? geometry.size.width * 0.2 : 0.0

                VStack {
                    ScrollView {
                        VStack {
                            if viewModel.shoppingList.isEmpty {
                                EmptyListView(isLandscape: isLandscape)
                            } else {
                                shoppingListItemsView
                                    .padding(.horizontal, horizontalPadding)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadShoppingListFromServer()
                        await viewModel.loadLabels()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)

                    Spacer()

                    inputSection(padding: horizontalPadding)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .overlay(
                    Group {
                        if showSuccessToast {
                            Text(LocalizedStringProvider.localized("add_success"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .transition(.opacity)
                                .padding(.bottom, 100)
                        }
                    },
                    alignment: .bottom
                )
                .alert(isPresented: $showArchiveAlert) {
                    Alert(
                        title: Text(LocalizedStringProvider.localized("list_done_title")),
                        message: Text(LocalizedStringProvider.localized("list_done_message")),
                        dismissButton: .default(Text(LocalizedStringProvider.localized("ok")))
                    )
                }
                .onAppear {
                    configureAPIIfNeeded()
                    Task {
                        await viewModel.loadShoppingListFromServer()
                        await viewModel.loadLabels()
                    }
                }
                .onReceive(Publishers.keyboardHeight) { newHeight in
                    withAnimation {
                        self.keyboardHeight = newHeight
                    }
                }
                .navigationTitle(" \(LocalizedStringProvider.localized("shopping_list"))")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var shoppingListItemsView: some View {
        let grouped = Dictionary(grouping: viewModel.shoppingList) { item in
            item.label?.name ?? LocalizedStringProvider.localized("unlabeled_category")
        }

        let sortedCategories = grouped
            .filter { !$0.value.isEmpty }
            .keys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        return VStack(spacing: 0) {
            ForEach(sortedCategories, id: \.self) { category in
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation {
                            if collapsedCategories.contains(category) {
                                collapsedCategories.remove(category)
                            } else {
                                collapsedCategories.insert(category)
                            }
                        }
                    }) {
                        HStack {
                            Text(category)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: collapsedCategories.contains(category) ? "chevron.down" : "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if !collapsedCategories.contains(category) {
                        let items = grouped[category] ?? []
                        let sortedItems = items.sorted { !$0.checked && $1.checked }

                        ForEach(sortedItems) { item in
                            ShoppingListItemView(item: item) {
                                viewModel.toggleIngredientCompletion(item)
                            }
                        }
                        .onDelete(perform: viewModel.deleteIngredient)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom)
    }

    private func inputSection(padding: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                TextField(LocalizedStringProvider.localized("add_item_placeholder"), text: $newItemNote)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                    .focused($isInputFocused)
                    .onSubmit {
                        addItem()
                    }

                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                }
                .disabled(newItemNote.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Horizontale Kategorieauswahl
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(label: nil, name: LocalizedStringProvider.localized("unlabeled_category"))
                    ForEach(viewModel.availableLabels, id: \.id) { label in
                        categoryChip(label: label, name: label.name)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Button nur anzeigen wenn kein Fokus
            if !isInputFocused {
                Button {
                    viewModel.archiveList()
                    showArchiveAlert = true
                } label: {
                    HStack {
                        Image(systemName: "archivebox.fill")
                        Text(LocalizedStringProvider.localized("complete_shopping"))
                    }
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, padding > 0 ? padding : 16)
        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 12)
        .animation(.easeOut(duration: 0.3), value: keyboardHeight)
        .animation(.easeInOut, value: isInputFocused)
    }

    private func categoryChip(label: ShoppingItem.LabelWrapper?, name: String) -> some View {
        let isSelected = selectedLabel?.id == label?.id

        return Text(name)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
            .foregroundColor(isSelected ? Color.accentColor : .primary)
            .cornerRadius(20)
            .onTapGesture {
                selectedLabel = label
            }
    }

    private func addItem() {
        let trimmed = newItemNote.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        viewModel.addManualIngredient(note: trimmed, label: selectedLabel)
        newItemNote = ""
        selectedLabel = nil
        isInputFocused = true

        withAnimation {
            showSuccessToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSuccessToast = false
            }
        }
    }

    private func configureAPIIfNeeded() {
        // Optional: Header oder Auth konfigurieren
    }
}

// MARK: - Unteransichten

struct ShoppingListItemView: View {
    let item: ShoppingItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(item.note ?? "-")
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
                    .strikethrough(item.checked, color: .gray)
                    .foregroundColor(item.checked ? .gray : .primary)

                Spacer()

                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(item.checked ? .green : .gray)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyListView: View {
    let isLandscape: Bool

    var body: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(width: isLandscape ? 120 : 80, height: isLandscape ? 120 : 80)
                .foregroundColor(.green)
                .shadow(radius: 4)

            Text(LocalizedStringProvider.localized("shopping_done_title"))
                .font(isLandscape ? .title : .title2)
                .fontWeight(.semibold)

            Text(LocalizedStringProvider.localized("shopping_done_subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        Spacer()
    }
}

// MARK: - Keyboard Height Publisher

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .map { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return 0
                }
                return frame.height
            }
            .eraseToAnyPublisher()
    }
}
