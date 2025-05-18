import SwiftUI

struct WelcomeView: View {
    let settings = AppSettings.shared
    @StateObject private var leftoverViewModel = LeftoverRecipeViewModel()
    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 40)
                    
                    Text(LocalizedStringProvider.localized("welcome_title"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text(LocalizedStringProvider.localized("select_option"))
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        NavigationLink(destination: RecipeListView()) {
                            gridButtonLabel(LocalizedStringProvider.localized("show_recipes"), iconName: "book.fill", count: 0)
                        }
                        
                        NavigationLink(destination: ShoppingListView()) {
                            gridButtonLabel(LocalizedStringProvider.localized("shopping_list"), iconName: "cart.fill", count: shoppingListViewModel.uncheckedItemCount)
                        }
                        
                        NavigationLink(destination: ArchivedShoppingListsView()) {
                            gridButtonLabel(LocalizedStringProvider.localized("archived_lists"), iconName: "archivebox.fill", count: 0)
                        }
                        
                        NavigationLink(destination: RecipeUploadView()) {
                            gridButtonLabel(LocalizedStringProvider.localized("recipe_upload"), iconName: "plus")
                        }
                        
                        NavigationLink(destination: MealplanView()) {
                            gridButtonLabel(LocalizedStringProvider.localized("meal_plan"), iconName: "calendar")
                        }
                        
                        NavigationLink(destination: LeftoverRecipeFinderView(viewModel: leftoverViewModel)) {
                            gridButtonLabel(LocalizedStringProvider.localized("leftover.title"), iconName: "leaf.fill")
                        }
                        
                        NavigationLink(destination: SetupView(isInitialSetup: false)) {
                            gridButtonLabel(LocalizedStringProvider.localized("settings"), iconName: "gearshape.fill")
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .onAppear {
                if settings.isConfigured,
                   let url = URL(string: settings.serverURL) {
                    
                    var headers: [String: String] = [:]
                    if settings.sendOptionalHeaders {
                        headers[settings.optionalHeaderKey1] = settings.optionalHeaderValue1
                        headers[settings.optionalHeaderKey2] = settings.optionalHeaderValue2
                        headers[settings.optionalHeaderKey3] = settings.optionalHeaderValue3
                    }
                    
                    APIService.shared.configure(
                        baseURL: url,
                        token: settings.token,
                        optionalHeaders: headers
                    )
                    
                    print("✅ API konfiguriert mit \(url), optionale Header: \(headers)")
                } else {
                    print("⚠️ API nicht konfiguriert – Einstellungen fehlen")
                }
            }
        }
    }
    
    private func gridButtonLabel(_ text: String, iconName: String = "star", count: Int? = nil) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(minHeight: 80)
            
            VStack {
                HStack {
                    Image(systemName: iconName)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(15)
                    
                    Spacer()
                    
                    if let count = count {
                        Text("\(count)")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(15)
                    }
                }
                
                Spacer()
                
                HStack {
                    Text(text)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding([.leading, .bottom], 15)
                    Spacer()
                }
            }
        }
    }
}
