import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("didSeedExercises") private var didSeedExercises = false

    var body: some View {
        TabView {
            CalendarHomeView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            ContentView()
                .tabItem { Label("Workouts", systemImage: "list.bullet") }
        }
        .onAppear {
            if !didSeedExercises {
                ExerciseSeeder.seedIfNeeded(modelContext: modelContext)
                didSeedExercises = true
            }
            ExerciseSQLiteStore.shared.open()
        }
    }
}
