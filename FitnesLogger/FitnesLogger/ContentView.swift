import SwiftUI
import SwiftData

struct Workout: Identifiable {
    let id = UUID()
    var date: Date
    var title: String
    var entries: [ExerciseEntry]
}

struct ExerciseEntry: Identifiable {
    let id = UUID()
    var name: String
    var sets: [WorkoutSet]
}

struct WorkoutSet: Identifiable {
    let id = UUID()
    var weightKg: Double
    var reps: Int
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutModel.date, order: .reverse)
    private var workouts: [WorkoutModel]

    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { w in
                    NavigationLink {
                        WorkoutDetailView(workout: w)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(w.title).font(.headline)
                            Text(w.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        modelContext.delete(workouts[i])
                    }
                    do {
                        try modelContext.save()
                    } catch {
                        print("SAVE ERROR (delete):", error)
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddWorkoutView { newWorkout in
                    modelContext.insert(newWorkout)
                    do {
                        try modelContext.save()
                        print("Saved workout:", newWorkout.title)
                    } catch {
                        print("SAVE ERROR (insert):", error)
                    }
                }
            }
            }
        }
    }

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: WorkoutModel

    @State private var pickingExercise: ExerciseModel?
    @State private var showAddExercisePicker = false

    var body: some View {
        List {
            Section("Workout") {
                TextField("Title", text: $workout.title)
                DatePicker("Date", selection: $workout.date)
            }

            Section {
                Button {
                    showAddExercisePicker = true
                } label: {
                    Label("Add exercise", systemImage: "plus.circle.fill")
                }
            }

            ForEach(workout.entries) { exercise in
                ExerciseEditorSection(
                    exercise: exercise,
                    onChangeName: { pickingExercise = exercise }
                )
            }
            .onDelete(perform: deleteExercises)
        }
        .navigationTitle(workout.title.isEmpty ? "Workout" : workout.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
            }
        }
        .onChange(of: workout.title) { _, _ in save() }
        .onChange(of: workout.date) { _, _ in save() }

        // picker za "Change" pri obstoječi vaji
        .sheet(item: $pickingExercise) { ex in
            ExercisePickerSheet { picked in
                ex.name = picked
                save()
                pickingExercise = nil
            }
        }

        // picker za "Add exercise"
        .sheet(isPresented: $showAddExercisePicker) {
            ExercisePickerSheet { picked in
                addExercise(named: picked)
                showAddExercisePicker = false
            }
        }
    }

    private func addExercise(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let ex = ExerciseModel(name: trimmed)
        ex.workout = workout
        workout.entries.append(ex)

        save()
    }

    private func deleteExercises(_ indexSet: IndexSet) {
        for i in indexSet {
            let ex = workout.entries[i]
            modelContext.delete(ex)
        }
        save()
    }

    private func save() {
        do { try modelContext.save() }
        catch { print("SAVE ERROR (detail):", error) }
    }
}

struct ExerciseEditorSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: ExerciseModel

    let onChangeName: () -> Void

    var body: some View {
        Section {
            HStack {
                Text(exercise.name.isEmpty ? "Exercise" : exercise.name)
                    .font(.headline)
                Spacer()
                Button("Change") { onChangeName() }
                    .font(.caption)
            }

            ForEach(exercise.sets) { set in
                SetRow(set: set)
            }
            .onDelete(perform: deleteSets)

            Button("Add set") { addSet() }
                .font(.caption)

        } header: {
            Text(exercise.name.isEmpty ? "Exercise" : exercise.name)
        }
    }

    private func addSet() {
        let s = WorkoutSetModel(weightKg: 0, reps: 8)
        s.exercise = exercise
        exercise.sets.append(s)
        save()
    }

    private func deleteSets(_ indexSet: IndexSet) {
        for i in indexSet {
            let s = exercise.sets[i]
            modelContext.delete(s)
        }
        save()
    }

    private func save() {
        do { try modelContext.save() }
        catch { print("SAVE ERROR (exercise):", error) }
    }
}
struct SetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var set: WorkoutSetModel

    private let weightFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Text("kg:")
                .foregroundStyle(.secondary)

            TextField("0", value: $set.weightKg, formatter: weightFormatter)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)

            Stepper("Reps: \(set.reps)", value: $set.reps, in: 1...50)
        }
        .onChange(of: set.weightKg) { _, _ in save() }
        .onChange(of: set.reps) { _, _ in save() }
    }

    private func save() {
        do { try modelContext.save() }
        catch { print("SAVE ERROR (set):", error) }
    }
}

struct ExercisePickerTarget: Identifiable {
    let id: UUID
}
struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pickingExerciseID: UUID?
    @State private var title: String = ""
    @State private var date: Date = .now
    @State private var pickingExercise: ExercisePickerTarget?

    @State private var exercises: [ExerciseEntry] = []

    let onSave: (WorkoutModel) -> Void
    private let weightFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()
    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Title (e.g. Push)", text: $title)
                    DatePicker("Date", selection: $date)
                }

                Section("Exercises") {
                    ForEach($exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(exercise.name.isEmpty ? "Choose exercise…" : exercise.name)
                                    .font(.headline)

                                Spacer()

                                Button(exercise.name.isEmpty ? "Choose" : "Change") {
                                    pickingExercise = ExercisePickerTarget(id: exercise.id)
                                }
                                .font(.caption)
                            }

                            ForEach($exercise.sets) { $set in
                                HStack(spacing: 12) {
                                    Text("kg:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    TextField("0", value: $set.weightKg, formatter: weightFormatter)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                    Stepper("Reps: \(set.reps)", value: $set.reps, in: 1...50)
                                }
                            }
                            .onDelete { indexSet in
                                exercise.sets.remove(atOffsets: indexSet)
                            }

                            Button("Add set") {
                                exercise.sets.append(
                                    WorkoutSet(weightKg: 0, reps: 8)
                                )
                            }
                            .font(.caption)
                        }
                    }
                    .onDelete { indexSet in
                        exercises.remove(atOffsets: indexSet)
                    }

                    Button("Add exercise") {
                        exercises.append(
                            ExerciseEntry(
                                name: "",
                                sets: [WorkoutSet(weightKg: 0, reps: 8)]
                            )
                        )
                    }
                }
            }
            .navigationTitle("New Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let workout = WorkoutModel(date: date, title: title.isEmpty ? "Workout" : title)
                        
                        for ex in exercises {
                            let exercise = ExerciseModel(name: ex.name.isEmpty ? "Exercise" : ex.name)
                            exercise.workout = workout   // <- poveže exercise z workoutom
                            
                            for uiSet in ex.sets {
                                let s = WorkoutSetModel(weightKg: uiSet.weightKg, reps: uiSet.reps)
                                s.exercise = exercise     // <- poveže set z exercise (inverse naredi ostalo)
                            }
                        }
                        
                        onSave(workout)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || exercises.isEmpty)
                }
            }
            .sheet(item: $pickingExercise) { target in
                ExercisePickerSheet { picked in
                    if let idx = exercises.firstIndex(where: { $0.id == target.id }) {
                        exercises[idx].name = picked
                    }
                    pickingExercise = nil
                }
            }
        }
    }
}
