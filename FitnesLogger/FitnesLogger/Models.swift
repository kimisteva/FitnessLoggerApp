import Foundation
import SwiftData

@Model
final class ExerciseCatalogModel {
    @Attribute(.unique) var name: String
    var category: String?   // npr. Chest, Back, Legs …

    init(name: String, category: String? = nil) {
        self.name = name
        self.category = category
    }
}
@Model
final class WorkoutModel {
    var date: Date
    var title: String

    // inverse je TUKAJ (array stran)
    @Relationship(deleteRule: .cascade, inverse: \ExerciseModel.workout)
    var entries: [ExerciseModel] = []

    init(date: Date = .now, title: String) {
        self.date = date
        self.title = title
    }
}

@Model
final class ExerciseModel {
    var name: String
    var muscleGroup: String?

    // brez inverse tukaj
    var workout: WorkoutModel?

    // inverse je TUKAJ (array stran)
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSetModel.exercise)
    var sets: [WorkoutSetModel] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class WorkoutSetModel {
    var weightKg: Double
    var reps: Int

    // brez inverse tukaj
    var exercise: ExerciseModel?

    init(weightKg: Double, reps: Int) {
        self.weightKg = weightKg
        self.reps = reps
    }
}
