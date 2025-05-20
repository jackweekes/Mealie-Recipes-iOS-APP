import SwiftUI

@main
struct MealieRecipesApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var viewModel = ShoppingListViewModel()

    init() {
        if AppSettings.shared.isConfigured {
            AppSettings.shared.configureAPIService()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.isConfigured {
                    WelcomeView()
                        .environmentObject(viewModel)
                } else {
                    SetupView()
                }
            }
            .environmentObject(settings)
            .environmentObject(viewModel)
            .id(settings.selectedLanguage)
        }
    }
}
