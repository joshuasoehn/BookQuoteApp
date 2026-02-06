//
//  AddQuoteSheet.swift
//  BookQuotes
//
//  A sheet for adding a new quote to a book.
//  Supports camera capture with OCR and manual text entry.
//

import SwiftUI
import SwiftData

/// The input mode for adding a quote
enum QuoteInputMode: String, CaseIterable {
    case camera = "Camera"
    case manual = "Manual"
}

/// Image picker source wrapper that conforms to Identifiable for sheet presentation
enum ImagePickerSource: Identifiable {
    case camera
    case photoLibrary
    
    var id: String {
        switch self {
        case .camera: return "camera"
        case .photoLibrary: return "photoLibrary"
        }
    }
    
    var sourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera: return .camera
        case .photoLibrary: return .photoLibrary
        }
    }
}

/// A form sheet for adding a new quote to a specific book.
struct AddQuoteSheet: View {
    // MARK: - Environment
    
    /// Used to dismiss this sheet
    @Environment(\.dismiss) private var dismiss
    
    /// Access to SwiftData for saving the new quote
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    /// The book to add the quote to
    let book: Book
    
    /// The initial input mode (defaults to camera)
    let initialMode: QuoteInputMode
    
    /// An optional initial image for OCR processing
    let initialImage: UIImage?
    
    // MARK: - Initializer
    
    init(book: Book, initialMode: QuoteInputMode = .camera, initialImage: UIImage? = nil) {
        self.book = book
        self.initialMode = initialMode
        self.initialImage = initialImage
    }
    
    // MARK: - State
    
    /// The quote text entered by the user
    @State private var quoteText = ""
    
    /// The page number as a string (for TextField compatibility)
    @State private var pageNumberString = ""
    
    /// Whether OCR processing is in progress
    @State private var isProcessing = false
    
    /// Error message to display
    @State private var errorMessage: String?
    
    /// Whether to show the error alert
    @State private var showingError = false
    
    /// The OCR service instance
    private let ocrService = UnderlineOCRService()
    
    // MARK: - Computed Properties
    
    /// Validation: quote text must be non-empty
    private var isValid: Bool {
        !quoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Converts the page number string to an Int (nil if empty or invalid)
    private var pageNumber: Int? {
        Int(pageNumberString)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Show processing state when OCR is running
                if isProcessing {
                    processingSection
                }
                
                // Show text input when not processing
                if !isProcessing {
                    textInputSection
                }
            }
            .navigationTitle("Add Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel button
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                // Save button (primary action)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveQuote()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .disabled(!isValid || isProcessing)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .presentationDetents([.medium, .large])
        // Use solid background instead of translucent glass material
        .presentationBackground(.background)
        .onAppear {
            // If an initial image was provided, process it for OCR
            if let image = initialImage {
                processImage(image)
            }
        }
    }
    
    // MARK: - Processing Section
    
    @ViewBuilder
    private var processingSection: some View {
        Section {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Analyzing image with AI...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Looking for underlined text")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Text Input Section
    
    @ViewBuilder
    private var textInputSection: some View {
        // Quote text input
        Section {
            TextField(
                "Enter quote text...",
                text: $quoteText,
                axis: .vertical
            )
            .lineLimit(5...10)
        } header: {
            Text("Quote")
        }
        
        // Page number input (optional)
        Section {
            TextField("Page number (optional)", text: $pageNumberString)
                .keyboardType(.numberPad)
        } header: {
            Text("Page")
        }
    }
    
    // MARK: - Actions
    
    /// Processes the captured image with OCR
    private func processImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await ocrService.extractUnderlinedText(from: image)
                
                await MainActor.run {
                    // Update state without animation for instant transition
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        quoteText = result.text
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isProcessing = false
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }
    
    /// Creates a new quote and saves it to the database
    private func saveQuote() {
        // Trim whitespace from the quote text
        let trimmedText = quoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the new quote
        let newQuote = Quote(text: trimmedText, pageNumber: pageNumber)
        
        // Link the quote to the book
        newQuote.book = book
        
        // Insert into the database
        modelContext.insert(newQuote)
        
        // Close the sheet
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let book = Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald")
    
    return AddQuoteSheet(book: book)
        .modelContainer(for: [Book.self, Quote.self], inMemory: true)
}
