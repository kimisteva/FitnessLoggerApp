import SwiftUI
import SwiftData

struct CalendarHomeView: View {
    @Environment(\.calendar) private var calendar
    @Query(sort: \WorkoutModel.date, order: .reverse) private var allWorkouts: [WorkoutModel]

    @State private var monthAnchor: Date = Date()         // kater mesec gledamo
    @State private var selectedDay: Date = Date()         // izbran dan (startOfDay)
    @State private var activeWorkout: WorkoutModel?


    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                monthHeader

                calendarGrid

                Divider()

                dayWorkoutsList
            }
            .padding(.horizontal)
            .navigationTitle("Calendar")
            .onAppear {
                selectedDay = calendar.startOfDay(for: Date())
                monthAnchor = Date()
            }
        }
        .sheet(item: $activeWorkout) { w in
            NavigationStack {
                WorkoutDetailView(workout: w)
            }
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                monthAnchor = calendar.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthAnchor, format: .dateTime.year().month(.wide))
                .font(.headline)

            Spacer()

            Button {
                monthAnchor = calendar.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Grid

    private var calendarGrid: some View {
        let days = daysForMonth(containing: monthAnchor) // vključno s “praznimi” celicami na začetku

        return VStack(spacing: 8) {
            // imena dni (pon–ned ali ned–sob, odvisno od locale)
            let symbols = calendar.veryShortWeekdaySymbolsShiftedToFirstWeekday()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(symbols, id: \.self) { s in
                    Text(s)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isInMonth = calendar.isDate(day, equalTo: monthAnchor, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let workoutCount = workoutsByDay[calendar.startOfDay(for: day)]?.count ?? 0

        Button {
            selectedDay = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(isSelected ? Color.primary.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Circle()
                    .frame(width: 6, height: 6)
                    .opacity(workoutCount > 0 ? 1 : 0)
            }
            .foregroundStyle(isInMonth ? .primary : .secondary)
            .opacity(isInMonth ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isInMonth) // če ne želiš klikat “sivih” dni
    }

    // MARK: - List for selected day

    private var dayWorkoutsList: some View {
        let dayKey = calendar.startOfDay(for: selectedDay)
        let workouts = workoutsByDay[dayKey] ?? []

        return VStack(alignment: .leading, spacing: 8) {
            Text(selectedDay, format: .dateTime.weekday(.wide).day().month().year())
                .font(.headline)
            Button {
                startWorkout(for: selectedDay)
            } label: {
                Label("Start workout", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 4)
            if workouts.isEmpty {
                Text("No workouts.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(workouts) { w in
                        NavigationLink {
                            WorkoutDetailView(workout: w) // tvoj editable view
                        } label: {
                            VStack(alignment: .leading) {
                                Text(w.title.isEmpty ? "Workout" : w.title)
                                    .font(.headline)
                                Text(w.date.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        // briše iz baze
                        for i in indexSet { modelDelete(workouts[i]) }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    private func startWorkout(for day: Date) {
        let w = WorkoutModel(date: day, title: "Workout")
        modelContext.insert(w)
        do {
            try modelContext.save()
            activeWorkout = w
        } catch {
            print("SAVE ERROR (start workout calendar):", error)
        }
    }

    // MARK: - Data helpers

    @Environment(\.modelContext) private var modelContext

    private func modelDelete(_ workout: WorkoutModel) {
        modelContext.delete(workout)
        do { try modelContext.save() }
        catch { print("SAVE ERROR (calendar delete):", error) }
    }

    private var workoutsByDay: [Date: [WorkoutModel]] {
        Dictionary(grouping: allWorkouts) { w in
            calendar.startOfDay(for: w.date)
        }
    }

    private func daysForMonth(containing date: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthInterval.start))
        else { return [] }

        // kolk “praznih” celic pred 1. dnem (glede na firstWeekday)
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmpty = (weekday - calendar.firstWeekday + 7) % 7

        var days: [Date] = []
        // dodaj dneve “prejšnjega meseca” kot filler (da grid lepo poravna)
        if leadingEmpty > 0 {
            for i in stride(from: leadingEmpty, to: 0, by: -1) {
                if let d = calendar.date(byAdding: .day, value: -i, to: firstOfMonth) {
                    days.append(d)
                }
            }
        }

        // dnevi v mesecu
        let dayCount = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        for offset in 0..<dayCount {
            if let d = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) {
                days.append(d)
            }
        }

        // zapolni do polnih tednov (7 stolpcev)
        while days.count % 7 != 0 {
            if let last = days.last, let next = calendar.date(byAdding: .day, value: 1, to: last) {
                days.append(next)
            } else { break }
        }
        return days
    }
}

// MARK: - Weekday symbols helper

private extension Calendar {
    func veryShortWeekdaySymbolsShiftedToFirstWeekday() -> [String] {
        // Apple vrne vedno od nedelje dalje; mi premaknemo glede na firstWeekday
        let symbols = self.veryShortWeekdaySymbols
        let shift = (firstWeekday - 1) % 7
        return Array(symbols[shift...] + symbols[..<shift])
    }
}


