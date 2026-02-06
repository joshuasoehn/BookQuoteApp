//
//  BookCardView.swift
//  BookQuotes
//
//  A card representing a single book in the carousel.
//  Expands when selected to show title and author.
//

import SwiftUI

/// A card view for a single book.
/// Shows a compact cover when unselected, expands to show details when selected.
struct BookCardView: View {
    // MARK: - Properties
    
    /// The book to display
    let book: Book
    
    /// Whether this book is currently selected
    let isSelected: Bool
    
    /// Callback when the card is tapped
    let onTap: () -> Void

    /// Callback when the user chooses Delete in the context menu (nil hides the menu)
    var onDelete: (() -> Void)? = nil

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                // Book cover (always visible)
                BookCoverView(book: book)
                    .opacity(isSelected ? 1 : 0.5)

                // Title and author — fixed height (110 - 12*2 padding) so ZStack can center content
                ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(3)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(Color(hex: "111111"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(book.author)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "333333"))
                            .lineLimit(1)
                    }
                }
                .frame(width: 160, height: 86)
                .opacity(isSelected ? 1 : 0.5)
            }
            .padding(12)
            .frame(height: 110)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(isSelected ? 0.1 : 0.05), lineWidth: 1)
            )
            // Drop shadow only on selected state
            .shadow(
                color: isSelected ? Color.black.opacity(0.1) : Color.clear,
                radius: 10,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        // Smooth animation for expansion/collapse
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Book Cover View

/// Displays a book cover image, or a grey placeholder if no image is available.
struct BookCoverView: View {
    let book: Book

    var body: some View {
        Group {
            // Priority 1: Local image data
            if let imageData = book.coverImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 90)
                    .clipped()
                    .cornerRadius(6)
            }
            // Priority 2: Remote image URL
            else if let urlString = book.coverImageURL,
                    let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 90)
                            .clipped()
                            .cornerRadius(6)
                    case .failure, .empty:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            }
            // Fallback: Grey placeholder
            else {
                placeholderView
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }

    /// Grey placeholder when no cover image is available
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.systemGray5))
            .frame(width: 60, height: 90)
    }
}

// MARK: - Previews

#Preview("Selected") {
    let book = Book(title: "The Great Gatsby or a longer title which wraps", author: "F. Scott Fitzgerald")
    
    return BookCardView(
        book: book,
        isSelected: true,
        onTap: { }
    )
    .padding()
    .background(Color(.systemGray6))
}

#Preview("Unselected") {
    let book = Book(title: "1984", author: "George Orwell")
    
    return BookCardView(
        book: book,
        isSelected: false,
        onTap: { }
    )
    .padding()
    .background(Color(.systemGray6))
}

#Preview("Both States") {
    HStack(spacing: 12) {
        BookCardView(
            book: Book(title: "Ways of Being: Animals, Plants, Machines", author: "James Bridle"),
            isSelected: true,
            onTap: { }
        )
        BookCardView(
            book: Book(title: "1984", author: "George Orwell"),
            isSelected: false,
            onTap: { }
        )
    }
    .padding()
    .background(Color(.systemGray6))
}

#Preview("Placeholder") {
    HStack {
        BookCoverView(book: Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald"))
        BookCoverView(book: Book(title: "1984", author: "George Orwell"))
    }
    .padding()
}

#Preview("With Cover Image") {
    // Using Open Library cover API
    let book = Book(
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        coverImageURL: "https://covers.openlibrary.org/b/isbn/9780743273565-M.jpg"
    )
    
    return BookCoverView(book: book)
        .padding()
}
