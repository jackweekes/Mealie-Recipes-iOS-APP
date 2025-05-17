import SwiftUI

struct WelcomeView: View {
    let settings = AppSettings.shared
    @StateObject private var leftoverViewModel = LeftoverRecipeViewModel()
    
    // Define grid layout: 2 columns, flexible width
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
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
                            gridButtonLabel(LocalizedStringProvider.localized("show_recipes"))
                        }
                        
                        NavigationLink(destination: ShoppingListView()) {
                            gridButtonLabel(LocalizedStringProvider.localized("shopping_list"))
                        }
                        
                        NavigationLink(destination: ArchivedShoppingListsView()) {
                            gridButtonLabel(LocalizedStringProvider.localized("archived_lists"))
                        }
                        
                        NavigationLink(destination: RecipeUploadView()) {
                            gridButtonLabel(LocalizedStringProvider.localized("recipe_upload"))
                        }
                        
                        NavigationLink(destination: MealplanView()) {
                            gridButtonLabel(LocalizedStringProvider.localized("meal_plan"))
                        }
                        
                        NavigationLink(destination: LeftoverRecipeFinderView(viewModel: leftoverViewModel)) {
                            gridButtonLabel(LocalizedStringProvider.localized("leftover.title"))
                        }
                        
                        NavigationLink(destination: SetupView(isInitialSetup: false)) {
                            gridButtonLabel(LocalizedStringProvider.localized("settings"))
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
    
    // Extract button style to avoid repetition
    private func gridButtonLabel(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
            .multilineTextAlignment(.center)
    }
}
