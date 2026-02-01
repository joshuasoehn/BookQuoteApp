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
    
    // MARK: - Body
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Book cover placeholder (always visible)
                BookCoverView(title: book.title)
                    .opacity(isSelected ? 1 : 0.5)
                
                // Title and author (always visible, but faded when not selected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(Color(hex: "111111"))
                    
                    Text(book.author)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "333333"))
                        .lineLimit(1)
                }
                .frame(maxWidth: 160, alignment: .leading)
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
        // Smooth animation for expansion/collapse
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Book Cover View

/// A colored placeholder for a book cover.
/// Uses the book title to generate a consistent color.
struct BookCoverView: View {
    let title: String
    
    /// Generates a consistent color based on the title
    private var coverColor: Color {
        // Array of pleasant book cover colors
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .mint,
            .teal, .cyan, .blue, .indigo, .purple, .pink, .brown
        ]
        
        // Use the hash of the title to pick a color
        // abs() handles negative hash values
        let index = abs(title.hashValue) % colors.count
        return colors[index]
    }
    
    /// Gets initials or abbreviated title for the cover
    private var abbreviatedTitle: String {
        // Get first letters of first two words, or first two letters if single word
        let words = title.split(separator: " ")
        if words.count >= 2 {
            let first = words[0].prefix(1)
            let second = words[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else {
            return String(title.prefix(2)).uppercased()
        }
    }
    
    var body: some View {
        ZStack {
            // Colored background
            RoundedRectangle(cornerRadius: 6)
                .fill(coverColor.gradient)
                .frame(width: 60, height: 90)
            
            // Abbreviated title text
            Text(abbreviatedTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
    }
}

// MARK: - Previews

#Preview("Selected") {
    let book = Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald")
    
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

#Preview("Cover Colors") {
    HStack {
        BookCoverView(title: "The Great Gatsby")
        BookCoverView(title: "1984")
        BookCoverView(title: "Moby Dick")
        BookCoverView(title: "Pride and Prejudice")
    }
    .padding()
}
