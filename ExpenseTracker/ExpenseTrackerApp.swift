//
//  ExpenseTrackerApp.swift
//  ExpenseTracker
//
//  Created by 李可心(Daniel.L) on 2025/6/9.
//

import SwiftUI

@main
struct ExpenseTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
