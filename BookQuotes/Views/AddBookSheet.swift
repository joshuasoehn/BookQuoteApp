//
//  AddBookSheet.swift
//  BookQuotes
//
//  A sheet for adding a new book to the library.
//

import SwiftUI
import SwiftData

/// A form sheet for adding a new book.
struct AddBookSheet: View {
    // MARK: - Environment
    
    /// Used to dismiss this sheet
    @Environment(\.dismiss) private var dismiss
    
    /// Access to SwiftData for saving the new book
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    /// The title entered by the user
    @State private var title = ""
    
    /// The author entered by the user
    @State private var author = ""
    
    // MARK: - Computed Properties
    
    /// Validation: both title and author must be non-empty
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Title input
                Section {
                    TextField("Book Title", text: $title)
                        .textContentType(.none)
                        .autocorrectionDisabled(false)
                } header: {
                    Text("Title")
                }
                
                // Author input
                Section {
                    TextField("Author Name", text: $author)
                        .textContentType(.name)
                } header: {
                    Text("Author")
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel button
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                // Add button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addBook()
                    }
                    .disabled(!isValid)
                }
            }
        }
        // Use medium detent for a compact sheet
        .presentationDetents([.medium])
        // Use solid background instead of translucent glass material
        .presentationBackground(.background)
    }
    
    // MARK: - Actions
    
    /// Creates a new book and saves it to the database
    private func addBook() {
        // Trim whitespace from inputs
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create and insert the new book
        let newBook = Book(title: trimmedTitle, author: trimmedAuthor)
        modelContext.insert(newBook)
        
        // Close the sheet
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddBookSheet()
        .modelContainer(for: Book.self, inMemory: true)
}
