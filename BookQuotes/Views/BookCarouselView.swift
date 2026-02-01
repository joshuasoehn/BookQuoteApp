//
//  BookCarouselView.swift
//  BookQuotes
//
//  A horizontal scrolling carousel of book cards.
//  Shows an "Add" button followed by all books in the library.
//

import SwiftUI

/// A horizontal carousel displaying all books with an add button.
struct BookCarouselView: View {
    // MARK: - Properties
    
    /// All books to display in the carousel
    let books: [Book]
    
    /// The currently selected book (binding to parent state)
    @Binding var selectedBook: Book?
    
    /// Callback when the add button is tapped
    let onAddBook: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "Add Book" button as the first item
                AddBookButton(action: onAddBook)
                
                // All book cards
                ForEach(books) { book in
                    BookCardView(
                        book: book,
                        isSelected: selectedBook?.id == book.id,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedBook = book
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Add Book Button

/// A button for adding a new book, styled to match the book cards.
struct AddBookButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                // Document icon (SF Symbol for adding a book)
                Image(systemName: "book.pages")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "111111"))
            }
            .frame(width: 64, height: 110)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    // Create sample books for preview
    let sampleBooks = [
        Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald"),
        Book(title: "1984", author: "George Orwell"),
        Book(title: "To Kill a Mockingbird", author: "Harper Lee")
    ]
    
    return BookCarouselView(
        books: sampleBooks,
        selectedBook: .constant(sampleBooks[0]),
        onAddBook: { print("Add book tapped") }
    )
    .background(Color(.systemGray6))
}
