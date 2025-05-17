import SwiftUI

@main
struct MealieRecipesApp: App {
    @StateObject private var settings = AppSettings.shared
    @State private var viewModel: ShoppingListViewModel?

    init() {
        if AppSettings.shared.isConfigured {
            AppSettings.shared.configureAPIService()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.isConfigured {
                    if let viewModel = viewModel {
                        WelcomeView()
                            .environmentObject(viewModel)
                    } else {
                        WelcomeView()
                            .onAppear {
                                self.viewModel = ShoppingListViewModel()
                            }
                    }
                } else {
                    SetupView()
                }
            }
            .environmentObject(settings)
            .id(settings.selectedLanguage) // ✅ erzwingt Rebuild bei Sprachwechsel
        }
    }
}
