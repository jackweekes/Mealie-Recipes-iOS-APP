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
    @State private var showCompletedItems = true

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
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showCompletedItems.toggle()
                        }) {
                            Image(systemName: showCompletedItems ? "eye" : "eye.slash")
                        }
                        .accessibilityLabel(Text(showCompletedItems ? "Hide Completed Items" : "Show Completed Items"))
                    }
                }
            }
        }
    }

    private var shoppingListItemsView: some View {
        let filteredList = viewModel.shoppingList.filter { showCompletedItems || !$0.checked }

        let grouped = Dictionary(grouping: filteredList) { item in
            item.label?.name ?? LocalizedStringProvider.localized("unlabeled_category")
        }

        let sortedCategories = grouped
            .filter { !$0.value.isEmpty }
            .keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        return VStack(spacing: 0) {
            ForEach(sortedCategories, id: \.self) { category in
                let items = grouped[category] ?? []
                let labelColor = items.first?.label?.color
                let backgroundColor = Color(hex: labelColor) ?? Color(.systemGray6)
                let fgColor: Color = backgroundColor.brightness() < 0.5 ? .white : .black
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
                            Text(category.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)) // hides 1. , 2. , 3. , etc, useful for hidden sorting.
                                .font(.headline)
                                .foregroundColor(fgColor)
                            Spacer()
                            Image(systemName: collapsedCategories.contains(category) ? "chevron.down" : "chevron.right")
                                .foregroundColor(fgColor.opacity(0.7)) // slightly transparent for the icon
                                
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(backgroundColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if !collapsedCategories.contains(category) {
                        let items = grouped[category] ?? []
                        let sortedItems = items
                            .sorted { $0.note?.localizedStandardCompare($1.note ?? "") == .orderedAscending }
                            .sorted { !$0.checked && $1.checked } // keeps unchecked first

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
                    ForEach(viewModel.availableLabels.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, id: \.id) { label in // Sort A-Z
                        categoryChip(label: label, name: label.name.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression))
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
        .padding(.bottom, 12)
        .animation(.easeOut(duration: 0.1), value: keyboardHeight)
        .animation(.easeInOut, value: isInputFocused)
    }

    private func categoryChip(label: ShoppingItem.LabelWrapper?, name: String) -> some View {
        let isSelected = selectedLabel?.id == label?.id

        let color = Color(hex: label?.color)
        let backgroundColor = isSelected
            ? (color ?? Color.accentColor).opacity(0.2)
            : (color ?? Color(.systemGray5))
        let foregroundColor: Color = {
            if isSelected {
                return color?.brightness() ?? 0.5 < 0.5 ? .white : .accentColor
            } else {
                return color?.brightness() ?? 0.5 < 0.5 ? .white : .primary
            }
        }()

        return Text(name)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
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

extension Color {
    init?(hex: String?) {
        guard let hex = hex?.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), let int = UInt64(hex, radix: 16) else {
            return nil
        }

        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

extension Color {
    // Returns the brightness (perceived luminance) of the color (0 = dark, 1 = bright)
    func brightness() -> CGFloat {
        // Convert to UIColor to get RGB components
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Calculate luminance with standard formula
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}
