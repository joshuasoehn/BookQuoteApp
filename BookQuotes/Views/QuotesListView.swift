//
//  QuotesListView.swift
//  BookQuotes
//
//  Displays a list of quotes for the selected book.
//  Supports swipe-to-edit and swipe-to-delete.
//

import SwiftUI

/// A list view showing all quotes for a selected book.
struct QuotesListView: View {
    // MARK: - Properties
    
    /// The currently selected book (nil if none selected)
    let selectedBook: Book?
    
    /// Callback when user wants to edit a quote
    let onEdit: (Quote) -> Void
    
    /// Callback when user wants to delete a quote
    let onDelete: (Quote) -> Void
    
    // MARK: - Computed Properties
    
    /// Quotes sorted by date added (newest first)
    private var sortedQuotes: [Quote] {
        guard let book = selectedBook else { return [] }
        return book.quotes.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            // State 1: No book selected
            if selectedBook == nil {
                ContentUnavailableView(
                    "No Book Selected",
                    systemImage: "book.closed",
                    description: Text("Select a book from the carousel above or add a new one.")
                )
            }
            // State 2: Book selected but no quotes
            else if sortedQuotes.isEmpty {
                ContentUnavailableView(
                    "No Quotes Yet",
                    systemImage: "quote.bubble",
                    description: Text("Tap the button below to add your first quote from this book.")
                )
            }
            // State 3: Show quotes list
            else {
                List {
                    ForEach(sortedQuotes) { quote in
                        QuoteRowView(quote: quote)
                            // Remove default list row padding/insets
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            // Swipe RIGHT to edit
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    onEdit(quote)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            // Swipe LEFT to delete
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(quote)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

#Preview("With Quotes") {
    let book = Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald")
    book.quotes = [
        Quote(text: "So we beat on, boats against the current, borne back ceaselessly into the past."),
        Quote(text: "I hope she'll be a fool -- that's the best thing a girl can be in this world, a beautiful little fool.", pageNumber: 17),
        Quote(text: "In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since.", pageNumber: 1)
    ]
    
    return QuotesListView(
        selectedBook: book,
        onEdit: { _ in },
        onDelete: { _ in }
    )
}

#Preview("Empty") {
    let book = Book(title: "Empty Book", author: "No Author")
    
    return QuotesListView(
        selectedBook: book,
        onEdit: { _ in },
        onDelete: { _ in }
    )
}

#Preview("No Selection") {
    QuotesListView(
        selectedBook: nil,
        onEdit: { _ in },
        onDelete: { _ in }
    )
}
