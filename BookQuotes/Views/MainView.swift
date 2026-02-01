//
//  MainView.swift
//  BookQuotes
//
//  The main (and only) screen of the app.
//  Shows a book carousel at top and quotes list below.
//

import SwiftUI
import SwiftData

/// The main view of the BookQuotes app.
/// This is a single-screen app with a book carousel at the top
/// and a quotes list for the selected book below.
struct MainView: View {
    // MARK: - Environment
    
    /// Access to the SwiftData model context for saving/deleting
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Queries
    
    /// Fetches all books, sorted by date added (newest first)
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    
    // MARK: - State
    
    /// The currently selected book (shown in quotes list)
    @State private var selectedBook: Book?
    
    /// Controls whether the "Add Book" sheet is shown
    @State private var showingAddBook = false
    
    /// Controls whether the "Add Quote" sheet is shown
    @State private var showingAddQuote = false
    
    /// The quote being edited (nil when not editing)
    /// Using this as the item for .sheet(item:) presentation
    @State private var quoteToEdit: Quote?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Book carousel at the top
                BookCarouselView(
                    books: books,
                    selectedBook: $selectedBook,
                    onAddBook: { showingAddBook = true }
                )
                
                // Quotes list fills remaining space
                QuotesListView(
                    selectedBook: selectedBook,
                    onEdit: { quote in
                        quoteToEdit = quote
                    },
                    onDelete: { quote in
                        deleteQuote(quote)
                    }
                )
            }
            
            // Floating "Add Quote" button (only visible when a book is selected)
            if selectedBook != nil {
                VStack {
                    Spacer()
                    
                    Button {
                        showingAddQuote = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Add Quote")
                        }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        // Auto-select the first book when the view appears
        .onAppear {
            if selectedBook == nil && !books.isEmpty {
                selectedBook = books.first
            }
        }
        // Handle book deletion - select another book if the selected one was deleted
        .onChange(of: books) { oldBooks, newBooks in
            // If the selected book no longer exists, select the first available
            if let selected = selectedBook, !newBooks.contains(where: { $0.id == selected.id }) {
                selectedBook = newBooks.first
            }
        }
        // MARK: - Sheets
        .sheet(isPresented: $showingAddBook) {
            AddBookSheet()
        }
        .sheet(isPresented: $showingAddQuote) {
            // Only present if we have a selected book
            if let book = selectedBook {
                AddQuoteSheet(book: book)
            }
        }
        .sheet(item: $quoteToEdit) { quote in
            EditQuoteSheet(quote: quote)
        }
    }
    
    // MARK: - Actions
    
    /// Deletes a quote from the database
    private func deleteQuote(_ quote: Quote) {
        withAnimation {
            modelContext.delete(quote)
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .modelContainer(for: [Book.self, Quote.self], inMemory: true)
}
