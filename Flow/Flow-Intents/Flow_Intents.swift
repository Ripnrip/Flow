//
//  Flow_Intents.swift
//  Flow-Intents
//
//  Created by admin on 12/17/25.
//

import AppIntents

struct Flow_Intents: AppIntent {
    static var title: LocalizedStringResource { "Flow-Intents" }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
