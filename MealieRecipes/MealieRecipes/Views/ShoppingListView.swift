import SwiftUI
import Combine

struct ShoppingListView: View {
    @EnvironmentObject private var viewModel: ShoppingListViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var newItemNote: String = ""
    @State private var selectedLabel: ShoppingItem.LabelWrapper?
    @State private var showSuccessToast = false
    @State private var showArchiveAlert = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool
    @State private var itemToDelete: ShoppingItem? = nil
    @State private var showDeleteConfirmation = false
    @Environment(\.colorScheme) var colorScheme
    @State private var editingItem: ShoppingItem? = nil
    @State private var editedNote: String = ""
    @State private var editedLabel: ShoppingItem.LabelWrapper? = nil
    @State private var editedQuantity: Double? = nil
    @State private var showConnectionToast = false
    

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let horizontalPadding = isLandscape ? geometry.size.width * 0.2 : 0.0

                VStack(spacing: 0) {
                                ScrollView {
                                    VStack {
                                        if viewModel.shoppingList.isEmpty {
                                            EmptyListView(isLandscape: isLandscape)
                                        } else {
                                            shoppingListItemsView
                                                .padding(.horizontal, horizontalPadding)
                                                .padding(.top, 40)
                                        }
                                    }
                                }
                                .refreshable {
                                    await viewModel.loadShoppingListFromServer()
                                    await viewModel.loadLabels()
                                }
                                .frame(maxWidth: .infinity)
                                inputSection()

                            }
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
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                
                
                }
            }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    settings.showCompletedItems.toggle()
                }) {
                    Image(systemName: settings.showCompletedItems ? "eye" : "eye.slash")
                }
                .accessibilityLabel(Text(settings.showCompletedItems ? "Hide Completed Items" : "Show Completed Items"))
            }
        }
        
        
        .sheet(item: $editingItem) { item in
            EditShoppingItemView(
                viewModel: viewModel,
                item: item,
                note: $editedNote,
                label: $editedLabel,
                quantity: $editedQuantity,
                onSave: {
                    Task {
                        let success = await viewModel.updateIngredientOnServer(
                            itemID: item.id,
                            newNote: editedNote,
                            newLabel: editedLabel,
                            newQuantity: editedQuantity
                        )

                        if success {
                            editingItem = nil
                        } else {
                            // Optional: Show an error toast or alert
                            print("❌ Update failed, item not saved.")
                        }
                    }
                },
                onCancel: {
                    editingItem = nil
                },
                onDelete: {
                    editingItem = nil
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        itemToDelete = item
                    }
                },
                availableLabels: viewModel.availableLabels
            )
        }
        .alert(item: $itemToDelete) { item in
            Alert(
                title: Text("Delete Item?"),
                message: Text("Are you sure you want to delete \"\(item.note ?? "")\"?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let index = viewModel.shoppingList.firstIndex(where: { $0.id == item.id }) {
                        viewModel.deleteIngredient(at: IndexSet(integer: index))
                    }
                    itemToDelete = nil
                },
                secondaryButton: .cancel {
                    itemToDelete = nil
                }
            )
        }
    }

    private var shoppingListItemsView: some View {
        let filteredList = viewModel.shoppingList.filter { settings.showCompletedItems || !$0.checked }

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
                let backgroundColor = Color(hex: labelColor) ?? Color(.systemGray)
                let fgColor: Color = backgroundColor.brightness() < 0.5 ? .white : .black
                let backgroundColorParent = Color(.systemGray5)
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation {
                            if settings.collapsedLabels.contains(category) {
                                settings.collapsedLabels.remove(category)
                            } else {
                                settings.collapsedLabels.insert(category)
                            }
                        }
                    }) {
                        HStack {
                            let uncheckedCount = items.filter { !$0.checked }.count
                            let displayName = category.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                            HStack(spacing: 10) {
                                
                                Text(displayName)
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(backgroundColor)
                                    .background(backgroundColor)
                                    .foregroundColor(fgColor)
                                    .cornerRadius(16)

                               
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                Text("\(uncheckedCount)")
                                    .font(.system(size: 14))
                                    .frame(minWidth: 30)
                                    .padding(.vertical, 6)
                                    .background(backgroundColorParent)
                                    .foregroundColor(backgroundColorParent.brightness() < 0.5 ? .white : .black)
                                    .cornerRadius(16)
                                }
                            Image(systemName: settings.collapsedLabels.contains(category) ? "chevron.right" : "chevron.down")
                                .foregroundColor(backgroundColorParent.brightness() < 0.5 ? .white : .black)
                                .frame(width: 20, alignment: .trailing) // Fix width to avoid layout shift
                                
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(backgroundColorParent)
                        .background(.clear)
                        //.background(Color(.systemGroupedBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if !settings.collapsedLabels.contains(category) {
                        let items = grouped[category] ?? []
                        let sortedItems = items
                            .sorted { $0.note?.localizedStandardCompare($1.note ?? "") == .orderedAscending }
                            .sorted { !$0.checked && $1.checked } // keeps unchecked first

                        ForEach(sortedItems, id: \.id) { item in
                            VStack(spacing: 0) {
                                ShoppingListItemView(item: item, onTap: {
                                    viewModel.toggleIngredientCompletion(item)
                                }, onLongPress: {
                                    editingItem = item
                                    editedNote = item.note ?? ""
                                    editedLabel = item.label
                                    editedQuantity = item.quantity
                                })

                                if item.id != sortedItems.last?.id {
                                    Divider()
                                        .background(Color(.systemGray4))
                                        .padding(.leading, 10)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            viewModel.deleteIngredient(at: indexSet)
                        }
                        
                        
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
            }
        }
        .padding(.bottom)
    }
    


    @ViewBuilder
    private func inputSection() -> some View {
        if viewModel.isConnectedToAPI {
            VStack(spacing: 12) {
                // Prevent top-edge artifacts
                Color.clear
                    .frame(height: 0)
                    .frame(maxWidth: .infinity)

                // Input field + button
                HStack(spacing: 8) {
                    TextField(LocalizedStringProvider.localized("add_item_placeholder"), text: $newItemNote)
                        .padding(10)
                        .background(Color.clear) // fully transparent
                        .cornerRadius(12)
                        .focused($isInputFocused)
                        .font(.subheadline)
                        .onSubmit { addItem() }
                        .overlay( // Add a subtle border if needed, but transparent background
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor)
                    }
                    .disabled(newItemNote.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Label selector with fading gradients
                ZStack {
                    LabelChipSelector(
                        selectedLabel: $selectedLabel,
                        availableLabels: viewModel.availableLabels,
                        colorScheme: colorScheme
                    )
                    .background(Color.clear) // Ensure transparent background

                    HStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color(.systemBackground), .clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 20)
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, Color(.systemBackground)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 20)
                    }
                }
                .frame(height: 30)
                .clipped()

                if settings.showCompleteShoppingButton && !isInputFocused {
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
            .background(Color.clear) // Make sure the whole VStack is transparent
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .animation(.easeOut(duration: 0.2), value: keyboardHeight)
            .animation(.easeInOut, value: isInputFocused)
        } else {
            ConnectionLostToast()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.clear)
        }
    }

    private func categoryChip(label: ShoppingItem.LabelWrapper?, name: String) -> some View {
        let isSelected = selectedLabel?.id == label?.id

        // For unlabeled, set systemGray background, otherwise decode hex color
        let backgroundColor: Color = {
            if let label = label, let hexColor = Color(hex: label.color) {
                return hexColor
            } else {
                return Color(.systemGray) // unlabeled background color
            }
        }()

        // Foreground color based on brightness of background
        let foregroundColor: Color = backgroundColor.brightness() < 0.5 ? .white : .black

        return HStack(spacing: 8) {

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(foregroundColor)
                    .font(.subheadline)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            Text(name)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isSelected ? (colorScheme == .dark ? Color.white : Color.black) : backgroundColor,
                    lineWidth: 4
                )
        )
        .cornerRadius(20)
        .onTapGesture {
            selectedLabel = label
        }
    }

    private func addItem() {
        let trimmed = newItemNote.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        Task {
            await viewModel.addManualIngredient(note: trimmed, label: selectedLabel)

            newItemNote = ""
            selectedLabel = nil
            isInputFocused = false

            await viewModel.loadShoppingListFromServer()
            await viewModel.loadLabels()

            withAnimation {
                showSuccessToast = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showSuccessToast = false
                }
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
    let onLongPress: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack {
            if let quantity = item.quantity {
                Text("\(quantity.clean)")
                    .font(.system(size: 14))
                    .fontWeight(.regular)
                    .strikethrough(item.checked, color: .gray)
                    .foregroundColor(item.checked ? .gray : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(item.checked ? Color.clear : Color(.systemGray5))
                    )
            }
            Text(item.note ?? "-")
                .font(.system(size: 14))
                .fontWeight(.regular)
                .strikethrough(item.checked, color: .gray)
                .foregroundColor(item.checked ? .gray : .primary)
            
            Spacer()
            
            Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(item.checked ? .green : .gray)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPressed ? Color(.systemGray5) : Color(.systemGroupedBackground))
                .padding(8)
        )
        .contentShape(Rectangle())
        .cornerRadius(10)
        // Handle tap
        .onTapGesture {
            onTap()
        }
        .contextMenu { // right click support of macOS
            Button(action: {
                onLongPress()
            }) {
                Text("Edit Item")
                Image(systemName: "pencil")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        onLongPress()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
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

struct EditShoppingItemView: View {
    let viewModel: ShoppingListViewModel
    let item: ShoppingItem
    @Binding var note: String
    @Binding var label: ShoppingItem.LabelWrapper?
    @Binding var quantity: Double?

    var onSave: () -> Void
    var onCancel: () -> Void
    var onDelete: () -> Void
    let availableLabels: [ShoppingItem.LabelWrapper]

    @Environment(\.colorScheme) var colorScheme
    
        

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section(header: Text("Item Name")) {
                        TextField("Note", text: $note)
                    }

                    Section(header: Text("Quantity")) {
                        Stepper(value: Binding(
                            get: { quantity ?? 0 },
                            set: { quantity = $0 }
                        ), in: 1...100, step: 1) {
                            Text(quantity == nil ? "None" : "\(quantity!.clean)")
                        }

                        if quantity != 1 {
                            Button("Reset quantity") {
                                quantity = 1
                            }
                            .foregroundColor(.red)
                        }
                    }

                    Section(header: Text("Item Label")) {
                        LabelChipSelector(
                            selectedLabel: $label,
                            availableLabels: availableLabels,
                            colorScheme: colorScheme
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 0)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .navigationTitle("Edit Item")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onCancel()
                        }
                    }

                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                        
                        Button("Save") {
                            onSave()
                        }
                    }
                }

                if !viewModel.isConnectedToAPI {
                    ConnectionLostToast()
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: viewModel.isConnectedToAPI)
                }
            }
        }
    }
}

struct ConnectionLostToast: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 20))
                .foregroundColor(.red)

            Text("Connection to Mealie server lost.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)

            Text("Please check your internet connection or try again later.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct LabelChipSelector: View {
    @Binding var selectedLabel: ShoppingItem.LabelWrapper?
    var availableLabels: [ShoppingItem.LabelWrapper]
    var colorScheme: ColorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: nil, name: LocalizedStringProvider.localized("unlabeled_category"))

                ForEach(availableLabels.sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }, id: \.id) { label in
                    chip(label: label, name: label.name.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .frame(height: 30)
        .clipped()
    }

    @ViewBuilder
    private func chip(label: ShoppingItem.LabelWrapper?, name: String) -> some View {
        let isSelected = selectedLabel?.id == label?.id
        let backgroundColor: Color = {
            if let label = label, let hexColor = Color(hex: label.color) {
                return hexColor
            } else {
                return Color(.systemGray)
            }
        }()

        let foregroundColor: Color = backgroundColor.brightness() < 0.5 ? .white : .black

        HStack(spacing: 8) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(foregroundColor)
                    .font(.subheadline)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            Text(name)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.accentColor : backgroundColor, lineWidth: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))  // Ensures corners match
        .contentShape(RoundedRectangle(cornerRadius: 20)) // Improves tap behavior
        .onTapGesture {
            withAnimation {
                selectedLabel = label
            }
        }
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

extension Double {
    var clean: String {
        return truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }
}
