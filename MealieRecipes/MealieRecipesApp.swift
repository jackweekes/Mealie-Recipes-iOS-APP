import SwiftUI

@main
struct MealieRecipesApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var shoppingListViewModel = ShoppingListViewModel()

    init() {
        AppSettings.shared.configureAPIService()
    }

    var body: some Scene {
        WindowGroup {
            if settings.isConfigured {
                WelcomeView()
                    .environmentObject(shoppingListViewModel)
            } else {
                SetupView()
                    .environmentObject(shoppingListViewModel)
            }
        }
    }
}
