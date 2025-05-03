//
//  LocalizedStringProvider.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 02.05.25.
//


import Foundation

class LocalizedStringProvider {
    static func localized(_ key: String) -> String {
        let language = AppSettings.shared.selectedLanguage
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
