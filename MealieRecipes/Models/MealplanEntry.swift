//
//  MealplanEntry.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 04.05.25.
//



import Foundation

struct MealplanEntry: Codable, Identifiable {
    let id: Int
    let date: String
    let entryType: String
    let recipe: RecipeSummary?
    let title: String? //  wichtig für Freitexteinträge

    var slot: String { entryType }
}



struct MealplanRecipe: Codable {
    let id: String
    let name: String
    let image: String?
}


