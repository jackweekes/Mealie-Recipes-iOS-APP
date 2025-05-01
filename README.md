# Mealie-Recipes-iOS-APP
A native SwiftUI app for iOS and iPadOS that connects to your self-hosted Mealie server. Browse recipes, manage your shopping list, and cook with smart timers – all fully integrated via the Mealie API.


# Mealie iOS App (Community Project)

A native iOS app built with SwiftUI to connect to your self-hosted [Mealie](https://github.com/mealie-recipes/mealie) server via the official API.  
Designed for iPhone and iPad, this app brings recipe management and shopping lists to your fingertips – fully integrated with your Mealie instance.

---

## Features

### Setup
- Configure your Mealie server URL, API token, and optional custom headers.
- Quick access to recipes, shopping list, archived lists, and settings.

### Recipes
- Browse all recipes from your Mealie server.
- View and check off ingredients and preparation steps.
- Add ingredients (individually or all) to the shopping list.
- **Built-in Timer**: Start, modify, or cancel timers with audible alerts.
- **Ingredient Scaling**: Instantly view 0.5x, 1x, 2x, or 3x ingredient quantities.

### Shopping List
- Fully synced with Mealie’s shopping list API.
- Check items to mark them as completed on the server.
- Manually add items – with smart focus retention for fast entry.
- When completing a shopping trip, checked items are removed from Mealie and archived locally.

### Archive
- Stores completed shopping lists locally.
- Review or delete past lists anytime.

---

## Screenshots

*(Insert iPhone and iPad screenshots here)*

---

## Contributing

This project is open to the community! If you’re interested in testing, improving features, or contributing code, feel free to open an issue or pull request.  
Whether you're a Swift developer or just love Mealie – your feedback and support are welcome!

---

## Roadmap

- [ ] Offline mode
- [ ] Caching for recipes and shopping list
- [ ] **Recipe upload support**
- [ ] Multi-language support

---

## Requirements

- iOS 16+
- A running Mealie server (tested with API v2.8.0)

---

## License

MIT – see [LICENSE](LICENSE) file for details.
