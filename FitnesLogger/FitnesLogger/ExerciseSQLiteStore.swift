import Foundation
import Combine
import SQLite3
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class ExerciseSQLiteStore: ObservableObject {
    static let shared = ExerciseSQLiteStore()

    @Published private(set) var isReady: Bool = false

    private var db: OpaquePointer?
    private let dbFileName = "exercises.sqlite"

    private init() {}

    func open() {
        if isReady { return }

        let url = dbURL()
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            print("SQLite open failed:", errorMessage())
            return
        }

        // Create table
        let createSQL = """
        CREATE TABLE IF NOT EXISTS exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT
        );
        """
        if sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK {
            print("SQLite create table failed:", errorMessage())
            return
        }

        // Seed if empty
        if countExercises() == 0 {
            seedDefaults()
        }

        isReady = true
    }

    // MARK: - Queries

    func search(query: String, category: String?) -> [(name: String, category: String?)] {
        guard let db else { return [] }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let q = trimmed.isEmpty ? "%" : "%\(trimmed)%"

        let useCategory = {
            let c = (category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return c.isEmpty || c == "All" ? nil : c
        }()

        let sql: String
        if useCategory == nil {
            sql = """
            SELECT name, category
            FROM exercises
            WHERE name LIKE ? COLLATE NOCASE
            ORDER BY name
            LIMIT 200;
            """
        } else {
            sql = """
            SELECT name, category
            FROM exercises
            WHERE name LIKE ? COLLATE NOCASE AND category = ?
            ORDER BY name
            LIMIT 200;
            """
        }

        var stmt: OpaquePointer?
        var results: [(String, String?)] = []

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            print("SQLite prepare failed:", errorMessage())
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (q as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let cat = useCategory {
            sqlite3_bind_text(stmt, 2, (cat as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(stmt, 0))
            let catPtr = sqlite3_column_text(stmt, 1)
            let cat = catPtr != nil ? String(cString: catPtr!) : nil
            results.append((name, cat))
        }

        return results
    }


    func insertCustom(name: String, category: String? = nil) {
        guard let db else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let sql = "INSERT OR IGNORE INTO exercises (name, category) VALUES (?, ?);"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            print("SQLite prepare insert failed:", errorMessage())
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (trimmed as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let category {
            sqlite3_bind_text(stmt, 2, (category as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 2)
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("SQLite insert failed:", errorMessage())
        }
    }

    // MARK: - Helpers

    private func countExercises() -> Int {
        guard let db else { return 0 }
        let sql = "SELECT COUNT(*) FROM exercises;"
        var stmt: OpaquePointer?
        var count = 0

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            return 0
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            count = Int(sqlite3_column_int(stmt, 0))
        }
        return count
    }

    private func seedDefaults() {
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
            insertCustom(name: name, category: cat)
        }
    }

    private func dbURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(dbFileName)
    }

    private func errorMessage() -> String {
        if let db, let cStr = sqlite3_errmsg(db) {
            return String(cString: cStr)
        }
        return "Unknown SQLite error"
    }
}
