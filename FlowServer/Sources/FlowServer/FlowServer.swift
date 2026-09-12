import Foundation
import Hummingbird

/// 🚀 Entry point for the Flow Hummingbird backend.
@main
struct FlowServer {
    static func main() async throws {
        print("🌐 ✨ FlowServer awakening…")

        let realmService = try RealmService()
        try await realmService.seedSampleTaskIfNeeded()
        let config = await realmService.realmConfiguration()
        print("🗄️  Realm opened at: \(config.fileURL?.path ?? "in-memory")")

        let syncService = SupabaseSyncService(realmService: realmService)

        let router = Router(context: BasicRequestContext.self)
        router.middlewares.add(LogRequestsMiddleware(.info))
        router.middlewares.add(CORSMiddleware())

        let api = router.group("/api/v1")

        // 🌐 Task routes
        api.get("/tasks") { _, _ in
            try await realmService.allTasks()
        }

        api.get("/tasks/:id") { request, context in
            guard let idString = context.parameters.get("id"),
                  let id = UUID(uuidString: idString),
                  let task = try await realmService.task(id: id) else {
                throw HTTPError(.notFound)
            }
            return task
        }

        // ⏱️ Focus session routes
        api.post("/tasks/:id/sessions") { request, context in
            guard let idString = context.parameters.get("id"),
                  let id = UUID(uuidString: idString) else {
                throw HTTPError(.badRequest)
            }

            let body = try await context.requestDecoder.decode(FocusSessionRequest.self, from: request, context: context)
            return try await realmService.recordSession(taskId: id, body: body)
        }

        // 🔄 Sync routes
        api.post("/sync") { _, _ in
            let count = try await syncService.syncTasks()
            return MessageResponse(message: "🔄 Synced \(count) tasks from Supabase")
        }

        // 🧘 AMOR v5.7.0 — The Open Vein: ground-truth evidence relay.
        // Verbatim bytes only; every law stays client-side (harness-guarded).
        api.get("/amor/evidence") { _, _ in
            AMORRelay.evidence()
        }

        // 🧠 AMOR v5.7.0 — second-brain write-back (append-only daily note).
        api.post("/amor/brain") { request, context in
            let body = try await context.requestDecoder.decode(AMORBrainWriteRequest.self, from: request, context: context)
            return try AMORRelay.writeBrain(body)
        }


        router.get("/health") { _, _ in
            Response(status: .ok, body: .init(byteBuffer: .init(string: "🎉 FlowServer is alive")))
        }

        let app = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: 17777))
        )

        print("🌐 FlowServer listening on http://0.0.0.0:17777")
        try await app.runService()
    }
}
