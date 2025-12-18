import AppIntents
import SwiftUI // Required for @Environment, though often omitted if using external manager access
import ActivityKit // Required for LiveActivityIntent protocol (optional but good practice)
import SwiftData // Assuming Item needs SwiftData ModelContext access

// MARK: - Error Definition (Fix for "Cannot find 'IntentError' in scope")
private enum TaskIntentError: LocalizedError {
    case invalidTaskID(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTaskID(let id):
            return "The provided Task ID format is invalid: \(id)."
        }
    }
}

public struct FlowAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var snoozeCount: Int
        var moveCount: Int
        var startDate: Date
        var emoji: String
        var style: TaskStyle
        var lastInteractionDate: Date = .now
        var growthLevel: Int = 0
    }
    var taskId: String
}


// MARK: - 🧙‍♀️ Task Action Intents

// Utility function to check and retrieve the UUID
private func validateTaskID(_ taskId: String) throws -> UUID {
    guard let uuid = UUID(uuidString: taskId) else {
        throw TaskIntentError.invalidTaskID(taskId)
    }
    return uuid
}

// Base functionality placeholder to avoid repetition
private struct SharedTaskIntentLogic {
    static func perform(taskId: String, actionTitle: String) async throws -> some IntentResult {
        let uuid = try validateTaskID(taskId)
        
        // **NOTE**: To properly call TaskService, it would need to be instantiated or fetched, 
        // which requires accessing the ModelContainer. For a working solution, 
        // you must ensure TaskService(modelContext:) is invoked correctly in the main app context.
        
        // Placeholder for actual service call:
        // let taskService = // ... retrieve/initialize TaskService ...
        // await taskService.handleIntent(uuid, type: actionTitle) // or specific implementation
        
        print("\(actionTitle) Intent performed for Task ID: \(uuid)")
        return .result()
    }
}


// 💤 Action to Snooze the task
struct SnoozeIntent: AppIntent { // Struct conforming directly to AppIntent
    
    static var openAppWhenRun: Bool { false }
    static var title: LocalizedStringResource = "Snooze"
    
    // Parameter injected by the Live Activity context.attributes
    @Parameter(title: "Task Identifier")
    var taskId: String

    // Required by AppIntent standard conformance if non-default initializer exists, 
    // but typically not needed if only using memberwise for parameters.
    init(taskId: String) {
        self.taskId = taskId
    }
    
    // Memberwise initializer is synthesized if the above init() is removed, 
    // but for clarity when integrating with Live Activities parameters, we keep it simple.
    init() {
        self.taskId = ""
    }
    
    func perform() async throws -> some IntentResult {
        // Delegate to shared logic
        return try await SharedTaskIntentLogic.perform(taskId: taskId, actionTitle: "Snooze")
    }
}

// ✅ Action to Complete the task
struct DoneIntent: AppIntent { // Struct conforming directly to AppIntent
    
    static var openAppWhenRun: Bool { false }
    static var title: LocalizedStringResource = "Complete"
    
    // Parameter injected by the Live Activity context.attributes
    @Parameter(title: "Task Identifier")
    var taskId: String
    
    init(taskId: String) {
        self.taskId = taskId
    }
    
    init() {
        self.taskId = ""
    }
    
    func perform() async throws -> some IntentResult {
        // Delegate to shared logic
        return try await SharedTaskIntentLogic.perform(taskId: taskId, actionTitle: "Done")
    }
}
