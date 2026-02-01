//
//  QuoteRowView.swift
//  BookQuotes
//
//  A row displaying a single quote with underlined text styling.
//

import SwiftUI

/// A row view for displaying a single quote.
/// Shows the quote text with underline styling and optional page number.
struct QuoteRowView: View {
    // MARK: - Properties
    
    /// The quote to display
    let quote: Quote
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Quote text with grey underline styling
            Text(quote.text)
                .font(.system(size: 18))
                .lineSpacing(5) // Approximate line-height: 1.5
                .underline(true, color: Color(hex: "CCCCCC")) // Grey underline
                .foregroundColor(Color(hex: "111111"))
            
            // Optional page number
            if let pageNumber = quote.pageNumber {
                Text("Page \(pageNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24) // 24pt padding on all sides
        .overlay(
            // Bottom border
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}


// MARK: - Previews

#Preview("With Page Number") {
    let quote = Quote(
        text: "So we beat on, boats against the current, borne back ceaselessly into the past.",
        pageNumber: 180
    )
    
    return QuoteRowView(quote: quote)
        .padding()
}

#Preview("Without Page Number") {
    let quote = Quote(
        text: "It was the best of times, it was the worst of times, it was the age of wisdom, it was the age of foolishness."
    )
    
    return QuoteRowView(quote: quote)
        .padding()
}

#Preview("Long Quote") {
    let quote = Quote(
        text: "In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since. 'Whenever you feel like criticizing anyone,' he told me, 'just remember that all the people in this world haven't had the advantages that you've had.'",
        pageNumber: 1
    )
    
    return QuoteRowView(quote: quote)
        .padding()
}
