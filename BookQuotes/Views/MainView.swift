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
    
    /// The quote being edited (nil when not editing)
    /// Using this as the item for .sheet(item:) presentation
    @State private var quoteToEdit: Quote?
    
    /// The active image picker source for adding a quote (nil when not showing)
    @State private var quoteImagePickerSource: ImagePickerSource?
    
    /// Data for presenting the add quote sheet (nil when not showing)
    @State private var addQuoteData: AddQuoteData?

    /// Book pending delete confirmation (nil when no alert)
    @State private var bookToDelete: Book?

    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .top) {
            // Quotes list as full-screen background (scrolls underneath carousel)
            QuotesListView(
                selectedBook: selectedBook,
                onEdit: { quote in
                    quoteToEdit = quote
                },
                onDelete: { quote in
                    deleteQuote(quote)
                }
            )
            
            // Book carousel overlays on top with gradient fade
            BookCarouselView(
                books: books,
                selectedBook: $selectedBook,
                onAddBook: { showingAddBook = true },
                onDeleteBook: { book in
                    bookToDelete = book
                }
            )
            
            // Floating "Add Quote" button with pop-up menu (only visible when a book is selected)
            if selectedBook != nil {
                VStack {
                    Spacer()
                    
                    Menu {
                        // Take Photo option (only if camera is available)
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                quoteImagePickerSource = .camera
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }
                        }
                        
                        // Choose Photo option
                        Button {
                            quoteImagePickerSource = .photoLibrary
                        } label: {
                            Label("Choose Photo", systemImage: "photo.on.rectangle")
                        }
                        
                        // Add Manually option
                        Button {
                            if let book = selectedBook {
                                addQuoteData = AddQuoteData(book: book, mode: .manual)
                            }
                        } label: {
                            Label("Add Manually", systemImage: "square.and.pencil")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Add Quote")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "111111"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            // Liquid glass effect with white tint
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.9))
                                )
                        )
                        .clipShape(Capsule())
                        // Composite the view before applying shadow to prevent Menu clipping
                        .compositingGroup()
                        // Stronger drop shadow
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                        // Add padding so shadow has room to render
                        .padding(24)
                    }
                    .padding(-24) // Offset the padding so button position stays the same
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
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
        .alert("Delete Book?", isPresented: Binding(
            get: { bookToDelete != nil },
            set: { if !$0 { bookToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                bookToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let book = bookToDelete {
                    deleteBook(book)
                    bookToDelete = nil
                }
            }
        } message: {
            if let book = bookToDelete {
                Text("“\(book.title)” and all its quotes will be removed.")
            }
        }
        // MARK: - Sheets
        .sheet(isPresented: $showingAddBook) {
            AddBookSheet(onBookAdded: { book in
                selectedBook = book
            })
        }
        .sheet(item: $addQuoteData) { data in
            AddQuoteSheet(book: data.book, initialMode: data.mode, initialImage: data.image)
        }
        .sheet(item: $quoteToEdit) { quote in
            EditQuoteSheet(quote: quote)
        }
        // Image picker for camera/photo library
        .fullScreenCover(item: $quoteImagePickerSource) { source in
            ImagePickerView(
                sourceType: source.sourceType,
                onImageSelected: { image in
                    quoteImagePickerSource = nil
                    // Trigger the add quote sheet after a brief delay to allow picker to dismiss
                    if let book = selectedBook {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            addQuoteData = AddQuoteData(book: book, mode: .camera, image: image)
                        }
                    }
                },
                onCancel: {
                    quoteImagePickerSource = nil
                }
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Actions

    /// Deletes a book and all its quotes from the database
    private func deleteBook(_ book: Book) {
        withAnimation {
            modelContext.delete(book)
        }
    }

    /// Deletes a quote from the database
    private func deleteQuote(_ quote: Quote) {
        withAnimation {
            modelContext.delete(quote)
        }
    }
}

// MARK: - Add Quote Data

/// Data wrapper for presenting the add quote sheet
/// Holds the book, mode, and optional image together to avoid race conditions
struct AddQuoteData: Identifiable {
    let id = UUID()
    let book: Book
    let mode: QuoteInputMode
    let image: UIImage?
    
    init(book: Book, mode: QuoteInputMode, image: UIImage? = nil) {
        self.book = book
        self.mode = mode
        self.image = image
    }
}

// MARK: - Subtle Press Button Style

/// A button style with a subtle press effect (less opacity change than default)
struct SubtlePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("With Sample Data") {
    let container = try! ModelContainer(
        for: Book.self, Quote.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    // Book 1: The Great Gatsby
    let gatsby = Book(
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        coverImageURL: "https://covers.openlibrary.org/b/isbn/9780743273565-M.jpg"
    )
    container.mainContext.insert(gatsby)
    gatsby.quotes = [
        Quote(text: "So we beat on, boats against the current, borne back ceaselessly into the past.", pageNumber: 180),
        Quote(text: "I hope she'll be a fool — that's the best thing a girl can be in this world, a beautiful little fool.", pageNumber: 17),
        Quote(text: "In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since.", pageNumber: 1)
    ]
    
    // Book 2: 1984
    let nineteenEightyFour = Book(
        title: "1984",
        author: "George Orwell",
        coverImageURL: "https://covers.openlibrary.org/b/isbn/9780451524935-M.jpg"
    )
    container.mainContext.insert(nineteenEightyFour)
    nineteenEightyFour.quotes = [
        Quote(text: "War is peace. Freedom is slavery. Ignorance is strength.", pageNumber: 4),
        Quote(text: "Big Brother is watching you.", pageNumber: 2),
        Quote(text: "Who controls the past controls the future. Who controls the present controls the past.", pageNumber: 34)
    ]
    
    // Book 3: To Kill a Mockingbird
    let mockingbird = Book(
        title: "To Kill a Mockingbird",
        author: "Harper Lee",
        coverImageURL: "https://covers.openlibrary.org/b/isbn/9780060935467-M.jpg"
    )
    container.mainContext.insert(mockingbird)
    mockingbird.quotes = [
        Quote(text: "You never really understand a person until you consider things from his point of view... Until you climb inside of his skin and walk around in it.", pageNumber: 30),
        Quote(text: "The one thing that doesn't abide by majority rule is a person's conscience.", pageNumber: 105),
        Quote(text: "People generally see what they look for, and hear what they listen for.", pageNumber: 174)
    ]
    
    return MainView()
        .modelContainer(container)
}

#Preview("Empty") {
    MainView()
        .modelContainer(for: [Book.self, Quote.self], inMemory: true)
}
