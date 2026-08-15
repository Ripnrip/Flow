import Foundation
import RealmSwift

/// 🗄️ Actor-isolated wrapper around Realm so the non-Sendable `Realm` type
/// never leaks across Swift concurrency boundaries. A fresh Realm instance is
/// opened on the actor's executor for every operation, avoiding thread-confined
/// Realm access crashes.
actor RealmService {
    private let configuration: Realm.Configuration

    init() throws {
        self.configuration = Realm.Configuration(
            deleteRealmIfMigrationNeeded: true,
            objectTypes: [SuperTaskObject.self, FocusSessionObject.self]
        )
        // Warm up the Realm file path by opening once during init.
        _ = try Realm(configuration: configuration)
    }

    /// Exposes the Realm configuration so the server can log the file path.
    func realmConfiguration() -> Realm.Configuration {
        configuration
    }

    /// 🌱 Seeds a sample SuperProductivity task if the database is empty.
    /// Useful for local development when Supabase credentials are not configured.
    func seedSampleTaskIfNeeded() throws {
        let realm = try Realm(configuration: configuration)
        guard realm.objects(SuperTaskObject.self).isEmpty else { return }

        let sampleChecklistId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let sample = SuperTaskObject()
        sample.id = UUID()
        sample.name = "🎯 Focus on Flow integration"
        sample.taskDescription = "A sample task to verify the Hummingbird + Realm backend."
        sample.stateRaw = TaskState.open.rawValue
        sample.priority = 3
        sample.superChecklistId = sampleChecklistId
        sample.position = 1
        sample.createdAt = Date()
        sample.updatedAt = Date()
        sample.originalCreatedDate = Date()

        try realm.write {
            realm.add(sample)
        }
        print("🌱 Seeded sample task: \(sample.name)")
    }

    /// Returns all non-cancelled tasks sorted by position.
    func allTasks() throws -> [TaskDTO] {
        let realm = try Realm(configuration: configuration)
        let tasks = realm.objects(SuperTaskObject.self)
            .where { $0.stateRaw != "cancelled" }
            .sorted(byKeyPath: "position", ascending: true)
        return Array(tasks).map { $0.toDTO() }
    }

    /// Returns a single task by UUID, or nil if not found.
    func task(id: UUID) throws -> TaskDTO? {
        let realm = try Realm(configuration: configuration)
        guard let task = realm.object(ofType: SuperTaskObject.self, forPrimaryKey: id) else {
            return nil
        }
        return task.toDTO()
    }

    /// Records a focus session and updates the associated task.
    /// - Returns: A confirmation message.
    func recordSession(taskId: UUID, body: FocusSessionRequest) throws -> MessageResponse {
        let realm = try Realm(configuration: configuration)
        guard let task = realm.object(ofType: SuperTaskObject.self, forPrimaryKey: taskId) else {
            throw RealmServiceError.taskNotFound
        }

        try realm.write {
            let session = FocusSessionObject()
            session.startedAt = Date(timeIntervalSinceNow: -TimeInterval(body.durationSeconds))
            session.endedAt = body.endedAt
            session.durationSeconds = body.durationSeconds
            session.completedTask = body.completed
            task.sessions.append(session)

            let priorActual = task.actualDuration ?? 0
            task.actualDuration = priorActual + (body.durationSeconds / 60)
            task.updatedAt = Date()

            if body.completed {
                task.stateRaw = TaskState.done.rawValue
                task.completedAt = body.endedAt
            } else {
                task.stateRaw = TaskState.inProgress.rawValue
                task.startedAt = task.startedAt ?? session.startedAt
            }
        }

        return MessageResponse(message: "🎉 Focus session recorded for \(task.name)")
    }

    /// Upserts remote SuperProductivity tasks into Realm.
    func upsertTasks(_ remoteTasks: [RemoteSuperTask]) throws -> Int {
        let realm = try Realm(configuration: configuration)
        try realm.write {
            for remote in remoteTasks {
                let object = realm.object(ofType: SuperTaskObject.self, forPrimaryKey: remote.id)
                    ?? SuperTaskObject()

                if object.realm == nil {
                    object.id = remote.id
                    realm.add(object)
                }

                object.name = remote.name
                object.taskDescription = remote.taskDescription
                object.stateRaw = remote.state
                object.priority = remote.priority
                object.superChecklistId = remote.super_checklist_id
                object.parentTaskId = remote.parent_task_id
                object.estimatedDuration = remote.estimated_duration
                object.actualDuration = remote.actual_duration
                object.startedAt = remote.started_at
                object.completedAt = remote.completed_at
                object.originalCreatedDate = remote.original_created_date
                object.lastCarryoverDate = remote.last_carryover_date
                object.carryoverCount = remote.carryover_count
                object.dueDate = remote.due_date
                object.position = remote.position
                object.createdAt = remote.created_at
                object.updatedAt = remote.updated_at
                object.trelloId = remote.trello_id
                object.userId = remote.user_id
                object.reminderDate = remote.reminder_date
                object.alertDate = remote.alert_date
                object.addToCalendar = remote.add_to_calendar
                object.tags.removeAll()
                object.tags.append(objectsIn: remote.tags ?? [])
            }
        }
        return remoteTasks.count
    }
}

enum RealmServiceError: Error {
    case taskNotFound
}
