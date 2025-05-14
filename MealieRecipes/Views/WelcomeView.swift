import SwiftUI

struct WelcomeView: View {
    let settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                Text(LocalizedStringProvider.localized("welcome_title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(LocalizedStringProvider.localized("select_option"))
                    .font(.title2)
                    .foregroundColor(.secondary)

                Spacer()

                VStack(spacing: 20) {
                    NavigationLink(destination: RecipeListView()) {
                        Text(LocalizedStringProvider.localized("show_recipes"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: ShoppingListView()) {
                        Text(LocalizedStringProvider.localized("shopping_list"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: ArchivedShoppingListsView()) {
                        Text(LocalizedStringProvider.localized("archived_lists"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: RecipeUploadView()) {
                        Text(LocalizedStringProvider.localized("recipe_upload"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: MealplanView()) {
                        Text(LocalizedStringProvider.localized("meal_plan"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: SetupView(isInitialSetup: false)) {
                        Text(LocalizedStringProvider.localized("settings"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer()
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
}
