import SwiftUI
import SwiftData

@main
struct FitnessLoggerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WorkoutModel.self, ExerciseModel.self, WorkoutSetModel.self, ExerciseCatalogModel.self])
    }
}
