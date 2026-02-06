//
//  Book.swift
//  BookQuotes
//
//  SwiftData model representing a book in the user's library.
//

import Foundation
import SwiftData

/// A book that contains quotes.
/// Uses SwiftData's @Model macro to automatically handle persistence.
@Model
final class Book {
    // MARK: - Properties
    
    /// The title of the book
    var title: String
    
    /// The author of the book
    var author: String
    
    /// When this book was added to the library
    var dateAdded: Date
    
    /// Optional cover image stored as Data
    @Attribute(.externalStorage)
    var coverImageData: Data?
    
    /// Optional URL for fetching cover image (e.g., from Open Library)
    var coverImageURL: String?
    
    /// All quotes saved from this book.
    /// The cascade delete rule means when a book is deleted, all its quotes are also deleted.
    /// The inverse parameter links this back to Quote.book for bidirectional relationship.
    @Relationship(deleteRule: .cascade, inverse: \Quote.book)
    var quotes: [Quote] = []
    
    // MARK: - Initializer
    
    /// Creates a new book with the given title and author.
    /// - Parameters:
    ///   - title: The book's title
    ///   - author: The book's author
    ///   - coverImageURL: Optional URL for the book cover image
    ///   - dateAdded: When the book was added (defaults to now)
    init(title: String, author: String, coverImageURL: String? = nil, dateAdded: Date = Date()) {
        self.title = title
        self.author = author
        self.coverImageURL = coverImageURL
        self.dateAdded = dateAdded
    }
}
