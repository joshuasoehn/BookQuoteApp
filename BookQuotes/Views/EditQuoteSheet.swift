//
//  EditQuoteSheet.swift
//  BookQuotes
//
//  A sheet for editing an existing quote.
//

import SwiftUI
import SwiftData

/// A form sheet for editing an existing quote.
struct EditQuoteSheet: View {
    // MARK: - Environment
    
    /// Used to dismiss this sheet
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The quote being edited.
    /// Using @Bindable allows two-way binding to the @Model properties.
    @Bindable var quote: Quote
    
    // MARK: - State
    
    /// Local copy of the quote text for editing
    @State private var editedText = ""
    
    /// Local copy of the page number for editing
    @State private var editedPageNumberString = ""
    
    // MARK: - Computed Properties
    
    /// Validation: quote text must be non-empty
    private var isValid: Bool {
        !editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Converts the page number string to an Int (nil if empty or invalid)
    private var editedPageNumber: Int? {
        Int(editedPageNumberString)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Quote text input
                Section {
                    TextField("Quote text", text: $editedText, axis: .vertical)
                        .lineLimit(5...10)
                } header: {
                    Text("Quote")
                }
                
                // Page number input (optional)
                Section {
                    TextField("Page number (optional)", text: $editedPageNumberString)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Page")
                }
                
                // Show which book this quote belongs to
                if let book = quote.book {
                    Section {
                        HStack {
                            Text("Book")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(book.title)
                                .lineLimit(3)
                                .foregroundColor(.primary)
                        }
                    } header: {
                        Text("From")
                    }
                }
            }
            .navigationTitle("Edit Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel button
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                // Save button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
        }
        // Populate fields with existing quote data when the sheet appears
        .onAppear {
            editedText = quote.text
            if let pageNumber = quote.pageNumber {
                editedPageNumberString = String(pageNumber)
            }
        }
        .presentationDetents([.medium, .large])
        // Use solid background instead of translucent glass material
        .presentationBackground(.background)
    }
    
    // MARK: - Actions
    
    /// Saves the edited values back to the quote
    private func saveChanges() {
        // Update the quote with trimmed text
        quote.text = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update page number (nil if empty or invalid)
        quote.pageNumber = editedPageNumber
        
        // Close the sheet
        // Note: SwiftData automatically saves changes to @Model objects
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let quote = Quote(
        text: "So we beat on, boats against the current, borne back ceaselessly into the past.",
        pageNumber: 180
    )
    
    return EditQuoteSheet(quote: quote)
        .modelContainer(for: [Book.self, Quote.self], inMemory: true)
}
