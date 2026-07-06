import Foundation
import Supabase

/// 🌉 Pulls SuperProductivity tasks from Supabase and persists them in Realm
/// via `RealmService`. This lets the Hummingbird backend act as the single
/// source of truth for Flow, while still mirroring the upstream SuperProductivity
/// cloud database.
actor SupabaseSyncService {
    private let realmService: RealmService
    private let supabase: SupabaseClient?

    init(realmService: RealmService) {
        self.realmService = realmService

        if let url = ProcessInfo.processInfo.environment["SUPABASE_URL"],
           let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
           let supabaseURL = URL(string: url) {
            self.supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: key)
        } else {
            self.supabase = nil
            print("🌙 SUPABASE_URL or SUPABASE_ANON_KEY not set; sync service will run in stub mode")
        }
    }

    /// Fetches open tasks from Supabase and upserts them into Realm.
    /// - Returns: The number of tasks synced.
    func syncTasks() async throws -> Int {
        guard let supabase else {
            print("🌙 Sync skipped: no Supabase credentials configured")
            return 0
        }

        let remoteTasks: [RemoteSuperTask] = try await supabase
            .from("super_tasks")
            .select()
            .eq("state", value: "open")
            .execute()
            .value

        let count = try await realmService.upsertTasks(remoteTasks)
        print("🎉 Synced \(count) tasks from Supabase into Realm")
        return count
    }
}

/// 📡 Minimal Codable shape of a Supabase `super_tasks` row.
/// Field names match the snake_case PostgreSQL columns.
struct RemoteSuperTask: Codable {
    let id: UUID
    let name: String
    let taskDescription: String?
    let state: String
    let priority: Int
    let super_checklist_id: UUID
    let parent_task_id: UUID?
    let estimated_duration: Int?
    let actual_duration: Int?
    let started_at: Date?
    let completed_at: Date?
    let original_created_date: Date
    let last_carryover_date: Date?
    let carryover_count: Int
    let tags: [String]?
    let due_date: Date?
    let position: Double
    let created_at: Date
    let updated_at: Date
    let trello_id: String?
    let user_id: UUID?
    let reminder_date: Date?
    let alert_date: Date?
    let add_to_calendar: Bool
}
