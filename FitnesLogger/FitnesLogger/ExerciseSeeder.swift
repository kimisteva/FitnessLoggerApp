import SwiftData
import Foundation

enum ExerciseSeeder {
    static func seedIfNeeded(modelContext: ModelContext) {
        var fetch = FetchDescriptor<ExerciseCatalogModel>() // <- brez fetchLimit
        fetch.fetchLimit = 1                                 // <- limit nastaviš tu

        if let first = try? modelContext.fetch(fetch), !first.isEmpty {
            return
        }

        let defaults: [(String, String)] = [
            ("Bench Press", "Chest"),
            ("Incline Dumbbell Press", "Chest"),
            ("Push-Up", "Chest"),
            ("Overhead Press", "Shoulders"),
            ("Lateral Raise", "Shoulders"),
            ("Pull-Up", "Back"),
            ("Lat Pulldown", "Back"),
            ("Barbell Row", "Back"),
            ("Deadlift", "Back"),
            ("Squat", "Legs"),
            ("Leg Press", "Legs"),
            ("Romanian Deadlift", "Legs"),
            ("Biceps Curl", "Arms"),
            ("Triceps Pushdown", "Arms"),
            ("Plank", "Core")
        ]

        for (name, cat) in defaults {
            modelContext.insert(ExerciseCatalogModel(name: name, category: cat))
        }

        do { try modelContext.save() }
        catch { print("SEED ERROR:", error) }
    }
}
