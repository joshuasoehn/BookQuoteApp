//
//  OpenLibraryService.swift
//  BookQuotes
//
//  Fetches book search results from the Open Library API.
//

import Foundation

/// A book result from Open Library search (not a persisted model).
struct BookSearchResult: Identifiable {
    let id: String
    let title: String
    let author: String
    let coverImageURL: String?
}

// MARK: - API Response Types

private struct OpenLibrarySearchResponse: Decodable {
    let docs: [OpenLibraryDoc]?
}

private struct OpenLibraryDoc: Decodable {
    let title: String?
    let author_name: [String]?
    let cover_i: Int?
}

// MARK: - Service

/// Service for searching books via the Open Library API.
final class OpenLibraryService {
    static let shared = OpenLibraryService()

    private let baseURL = "https://openlibrary.org/search.json"
    private let session = URLSession.shared
    private let maxResults = 15

    private init() {}

    /// Searches Open Library for books matching the query.
    /// - Parameter query: Search string (title or author).
    /// - Returns: Up to 15 book results with title, author, and optional cover URL.
    func search(query: String) async throws -> [BookSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?q=\(encoded)&limit=20")
        else { return [] }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: data)
        let docs = response.docs ?? []

        return docs
            .compactMap { doc -> BookSearchResult? in
                guard let title = doc.title, !title.isEmpty else { return nil }
                let author = (doc.author_name ?? []).joined(separator: ", ")
                let coverURL: String? = doc.cover_i.map { "https://covers.openlibrary.org/b/id/\($0)-M.jpg" }
                let id = "\(title)-\(author)-\(doc.cover_i ?? 0)"
                return BookSearchResult(id: id, title: title, author: author, coverImageURL: coverURL)
            }
            .prefix(maxResults)
            .map { $0 }
    }
}
