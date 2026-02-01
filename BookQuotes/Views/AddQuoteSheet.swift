//
//  AddQuoteSheet.swift
//  BookQuotes
//
//  A sheet for adding a new quote to a book.
//  Supports camera capture (Phase 3) and manual text entry.
//

import SwiftUI
import SwiftData

/// The input mode for adding a quote
enum QuoteInputMode: String, CaseIterable {
    case camera = "Camera"
    case manual = "Manual"
}

/// A form sheet for adding a new quote to a specific book.
struct AddQuoteSheet: View {
    // MARK: - Environment
    
    /// Used to dismiss this sheet
    @Environment(\.dismiss) private var dismiss
    
    /// Access to SwiftData for saving the new quote
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    /// The book to add the quote to
    let book: Book
    
    // MARK: - State
    
    /// The selected input mode (camera or manual)
    @State private var inputMode: QuoteInputMode = .manual
    
    /// The quote text entered by the user
    @State private var quoteText = ""
    
    /// The page number as a string (for TextField compatibility)
    @State private var pageNumberString = ""
    
    // MARK: - Computed Properties
    
    /// Validation: quote text must be non-empty
    private var isValid: Bool {
        !quoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Converts the page number string to an Int (nil if empty or invalid)
    private var pageNumber: Int? {
        Int(pageNumberString)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Input mode picker
                Section {
                    Picker("Input Method", selection: $inputMode) {
                        ForEach(QuoteInputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Camera mode (placeholder for Phase 3)
                if inputMode == .camera {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("OCR Coming in Phase 3")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Camera capture and text recognition will be added in a future update.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                
                // Manual entry mode
                if inputMode == .manual {
                    // Quote text input
                    Section {
                        TextField("Enter quote text...", text: $quoteText, axis: .vertical)
                            .lineLimit(5...10)
                    } header: {
                        Text("Quote")
                    }
                    
                    // Page number input (optional)
                    Section {
                        TextField("Page number (optional)", text: $pageNumberString)
                            .keyboardType(.numberPad)
                    } header: {
                        Text("Page")
                    }
                }
                
                // Show which book this quote will be added to
                Section {
                    HStack {
                        Text("Book")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(book.title)
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("Adding to")
                }
            }
            .navigationTitle("Add Quote")
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
                        saveQuote()
                    }
                    .disabled(!isValid || inputMode == .camera)
                }
            }
        }
        .presentationDetents([.medium, .large])
        // Use solid background instead of translucent glass material
        .presentationBackground(.background)
    }
    
    // MARK: - Actions
    
    /// Creates a new quote and saves it to the database
    private func saveQuote() {
        // Trim whitespace from the quote text
        let trimmedText = quoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the new quote
        let newQuote = Quote(text: trimmedText, pageNumber: pageNumber)
        
        // Link the quote to the book
        newQuote.book = book
        
        // Insert into the database
        modelContext.insert(newQuote)
        
        // Close the sheet
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let book = Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald")
    
    return AddQuoteSheet(book: book)
        .modelContainer(for: [Book.self, Quote.self], inMemory: true)
}
