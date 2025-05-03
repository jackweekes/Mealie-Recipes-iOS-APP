import SwiftUI
import Combine

struct ShoppingListView: View {
    @EnvironmentObject private var viewModel: ShoppingListViewModel
    @State private var newItemNote: String = ""
    @State private var showSuccessToast = false
    @State private var showArchiveAlert = false
    @State private var keyboardHeight: CGFloat = 0
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
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)

                    Spacer()

                    inputSection(padding: horizontalPadding)
                }
                .background(Color(.systemBackground).ignoresSafeArea())
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
                    }
                }
                .onReceive(Publishers.keyboardHeight) { newHeight in
                    withAnimation {
                        self.keyboardHeight = newHeight
                    }
                }
            }
        }
    }

    private var shoppingListItemsView: some View {
        let sortedList = viewModel.shoppingList.sorted { !$0.checked && $1.checked }
        return VStack(spacing: 0) {
            ForEach(sortedList) { item in
                ShoppingListItemView(item: item) {
                    viewModel.toggleIngredientCompletion(item)
                }
            }
            .onDelete(perform: viewModel.deleteIngredient)
        }
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
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

            if !viewModel.shoppingList.isEmpty {
                Button {
                    viewModel.archiveList()
                    showArchiveAlert = true
                } label: {
                    HStack {
                        Image(systemName: "archivebox.fill")
                        Text(LocalizedStringProvider.localized("complete_shopping"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, padding > 0 ? padding : 16)
        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 12)
        .animation(.easeOut(duration: 0.3), value: keyboardHeight)
    }

    private func addItem() {
        let trimmed = newItemNote.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        viewModel.addManualIngredient(note: trimmed)
        newItemNote = ""
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

struct ShoppingListItemView: View {
    let item: ShoppingItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(item.note ?? "-")
                    .strikethrough(item.checked, color: .gray)
                    .foregroundColor(item.checked ? .gray : .primary)
                Spacer()
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.checked ? .green : .gray)
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
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
