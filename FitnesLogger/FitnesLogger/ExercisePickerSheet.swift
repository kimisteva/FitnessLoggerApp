import SwiftUI

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var customName: String = ""
    @State private var selectedCategory: String = "All"

    private let categories = ["All", "Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio", "Full Body", "Other"]

    @ObservedObject private var store = ExerciseSQLiteStore.shared

    let onPick: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Search") {
                    TextField("Search exercises", text: $query)
                }

                // Če NE želiš muscle group filtra zgoraj, ta section lahko izbrišeš.
                // Če ga želiš, naj bo ločen section (ne znotraj Search).
                // Section("Muscle group") {
                //     Picker("Muscle group", selection: $selectedCategory) {
                //         ForEach(categories, id: \.self) { c in
                //             Text(c).tag(c)
                //         }
                //     }
                //     .pickerStyle(.segmented)
                // }

                Section("Pick from list") {
                    let results = store.search(query: query, category: selectedCategory)
                    ForEach(results, id: \.name) { item in
                        Button {
                            onPick(item.name)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                if let cat = item.category, !cat.isEmpty {
                                    Text(cat)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Custom exercise") {
                    TextField("Type your own", text: $customName)

                    Picker("Muscle group", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Use custom name") {
                        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }

                        store.insertCustom(name: name, category: selectedCategory)

                        onPick(name)
                        dismiss()
                    }
                    .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Choose exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { store.open() }
        }
    }
}
