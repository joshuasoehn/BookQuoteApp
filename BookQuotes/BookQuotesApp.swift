//
//  BookQuotesApp.swift
//  BookQuotes
//
//  Created by Joshua Söhn on 01.02.26.
//

import SwiftUI
import SwiftData

/// The main entry point for the BookQuotes app.
/// Sets up SwiftData with our Book and Quote models.
@main
struct BookQuotesApp: App {
    /// The shared model container that manages our SwiftData storage.
    /// This container holds both Book and Quote models.
    var sharedModelContainer: ModelContainer = {
        // Define the schema with our data models
        let schema = Schema([
            Book.self,
            Quote.self,
        ])
        
        // Configure the model storage (persisted to disk, not in-memory)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // MainView is our single-screen app interface
            MainView()
        }
        // Inject the model container so all views can access SwiftData
        .modelContainer(sharedModelContainer)
    }
}
