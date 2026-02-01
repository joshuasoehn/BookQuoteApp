//
//  Quote.swift
//  BookQuotes
//
//  SwiftData model representing a quote extracted from a book.
//

import Foundation
import SwiftData

/// A quote saved from a book.
/// Uses SwiftData's @Model macro to automatically handle persistence.
@Model
final class Quote {
    // MARK: - Properties
    
    /// The text content of the quote
    var text: String
    
    /// The page number where this quote was found (optional)
    var pageNumber: Int?
    
    /// When this quote was saved
    var dateAdded: Date
    
    /// The book this quote belongs to.
    /// This creates the inverse side of the Book.quotes relationship.
    var book: Book?
    
    // MARK: - Initializer
    
    /// Creates a new quote with the given text.
    /// - Parameters:
    ///   - text: The quote text
    ///   - pageNumber: Optional page number where the quote was found
    ///   - dateAdded: When the quote was saved (defaults to now)
    init(text: String, pageNumber: Int? = nil, dateAdded: Date = Date()) {
        self.text = text
        self.pageNumber = pageNumber
        self.dateAdded = dateAdded
    }
}
