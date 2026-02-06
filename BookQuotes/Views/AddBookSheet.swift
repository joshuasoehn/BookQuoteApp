//
//  AddBookSheet.swift
//  BookQuotes
//
//  A sheet for adding a new book to the library.
//  Supports search via Open Library and manual entry.
//

import SwiftUI
import SwiftData

/// A form sheet for adding a new book.
struct AddBookSheet: View {
    // MARK: - Environment

    /// Used to dismiss this sheet
    @Environment(\.dismiss) private var dismiss

    /// Access to SwiftData for saving the new book
    @Environment(\.modelContext) private var modelContext

    // MARK: - Properties

    /// Called with the newly added book when the user adds one (e.g. to auto-select it).
    var onBookAdded: ((Book) -> Void)? = nil

    // MARK: - State (search)

    /// Current search query
    @State private var searchText = ""

    /// Results from Open Library search
    @State private var searchResults: [BookSearchResult] = []

    /// Whether a search request is in progress
    @State private var isSearching = false

    /// Error message when search fails
    @State private var searchErrorMessage: String?

    /// When true, show the manual title/author form instead of search
    @State private var showManualEntry = false

    /// Current search task; cancelled when query changes
    @State private var searchTask: Task<Void, Never>?

    /// Focus for the search text field
    @FocusState private var isSearchFocused: Bool

    // MARK: - State (manual form)

    /// The title entered by the user (manual mode)
    @State private var title = ""

    /// The author entered by the user (manual mode)
    @State private var author = ""

    // MARK: - Computed Properties

    /// Validation: both title and author must be non-empty (manual mode)
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if showManualEntry {
                    manualEntryForm
                } else {
                    searchContent
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if showManualEntry {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            addBookManually()
                        }
                        .disabled(!isValid)
                    }
                }
            }
        }
        .presentationDetents([.fraction(1)])
        .presentationBackground(.background)
    }

    // MARK: - Search Content

    @ViewBuilder
    private var searchContent: some View {
        Form {
            Section {
                TextField("Search by title or author", text: $searchText)
                    .textContentType(.none)
                    .autocorrectionDisabled(false)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _, newValue in
                        runDebouncedSearch(query: newValue)
                    }
            }
            .onAppear {
                isSearchFocused = true
            }

            if searchText.isEmpty {

            } else if isSearching {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
            } else if let message = searchErrorMessage {
                Section {
                    Text(message)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(searchResults) { result in
                        Button {
                            addBook(from: result)
                        } label: {
                            BookSearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    if !searchResults.isEmpty {
                        Text("Results")
                    }
                }
            }

            Section {
                Button {
                    showManualEntry = true
                } label: {
                    Text("Can't find it? Add manually")
                }
            }
        }
    }

    // MARK: - Manual Entry Form

    @ViewBuilder
    private var manualEntryForm: some View {
        Form {
            Section {
                Button {
                    showManualEntry = false
                } label: {
                    Label("Search instead", systemImage: "magnifyingglass")
                }
            }

            Section {
                TextField("Book Title", text: $title)
                    .textContentType(.none)
                    .autocorrectionDisabled(false)
            } header: {
                Text("Title")
            }

            Section {
                TextField("Author Name", text: $author)
                    .textContentType(.name)
            } header: {
                Text("Author")
            }
        }
    }

    // MARK: - Actions

    private func runDebouncedSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchTask?.cancel()
            searchTask = nil
            isSearching = false
            searchResults = []
            searchErrorMessage = nil
            return
        }

        searchTask?.cancel()
        isSearching = true
        searchErrorMessage = nil

        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 s
                guard !Task.isCancelled else { return }
                let results = try await OpenLibraryService.shared.search(query: trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isSearching = false
                    searchResults = results
                    searchErrorMessage = nil
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchResults = []
                    searchErrorMessage = "Search failed. Try again or add manually."
                }
            }
        }
    }

    /// Creates a book from a search result and dismisses.
    private func addBook(from result: BookSearchResult) {
        let newBook = Book(
            title: result.title,
            author: result.author.isEmpty ? "Unknown" : result.author,
            coverImageURL: result.coverImageURL
        )
        modelContext.insert(newBook)
        onBookAdded?(newBook)
        dismiss()
    }

    /// Creates a new book from manual form and saves to the database.
    private func addBookManually() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let newBook = Book(title: trimmedTitle, author: trimmedAuthor)
        modelContext.insert(newBook)
        onBookAdded?(newBook)
        dismiss()
    }
}

// MARK: - Search Result Row

private struct BookSearchResultRow: View {
    let result: BookSearchResult

    var body: some View {
        HStack(spacing: 12) {
            coverThumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                if !result.author.isEmpty {
                    Text(result.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        let placeholder = RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: 44, height: 66)

        if let urlString = result.coverImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 66)
                        .clipped()
                        .cornerRadius(4)
                case .failure, .empty:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }
}

// MARK: - Preview

#Preview {
    AddBookSheet()
        .modelContainer(for: Book.self, inMemory: true)
}
