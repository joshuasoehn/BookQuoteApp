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
    
    // MARK: - State
    
    /// The selected input mode (camera or manual)
    @State private var inputMode: QuoteInputMode = .camera
    
    /// The quote text entered by the user
    @State private var quoteText = ""
    
    /// The page number as a string (for TextField compatibility)
    @State private var pageNumberString = ""
    
    // MARK: - Camera/OCR State
    
    /// The image selected from camera or photo library
    @State private var selectedImage: UIImage?
    
    /// Whether OCR processing is in progress
    @State private var isProcessing = false
    
    /// The active image picker source (nil when not showing)
    @State private var activeImagePicker: ImagePickerSource?
    
    /// Error message to display
    @State private var errorMessage: String?
    
    /// Whether to show the error alert
    @State private var showingError = false
    
    /// Whether underlines were detected (for info display)
    @State private var underlinesDetected: Bool?
    
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
    
    /// Check if camera is available
    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Input mode picker
                Section {
                    Picker("Input Method", selection: $inputMode) {
                        ForEach(QuoteInputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Camera mode
                if inputMode == .camera {
                    cameraSection
                }
                
                // Manual entry mode OR editing extracted text
                if inputMode == .manual || (inputMode == .camera && !quoteText.isEmpty) {
                    textInputSection
                }
                
                // Show which book this quote will be added to
                Section {
                    HStack {
                        Text("Book")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(book.title)
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("Adding to")
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
                
                // Save button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveQuote()
                    }
                    .disabled(!isValid || isProcessing)
                }
            }
            .sheet(item: $activeImagePicker) { source in
                ImagePickerView(
                    sourceType: source.sourceType,
                    onImageSelected: { image in
                        activeImagePicker = nil
                        selectedImage = image
                        processImage(image)
                    },
                    onCancel: {
                        activeImagePicker = nil
                    }
                )
                .ignoresSafeArea()
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
    }
    
    // MARK: - Camera Section
    
    @ViewBuilder
    private var cameraSection: some View {
        // Processing state
        if isProcessing {
            Section {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Detecting underlined text...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This may take a few seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        // No image selected yet - show capture buttons
        else if quoteText.isEmpty {
            Section {
                VStack(spacing: 16) {
                    // Camera button (if available)
                    if isCameraAvailable {
                        Button {
                            activeImagePicker = .camera
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    // Photo library button
                    Button {
                        activeImagePicker = .photoLibrary
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    // Info text
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("Take a photo of a book page with pencil underlines")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if !isCameraAvailable {
                            Text("Camera not available on this device")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } header: {
                Text("Capture Book Page")
            }
        }
        // Image captured and processed - show result info
        else {
            Section {
                VStack(spacing: 12) {
                    // Show thumbnail of captured image
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 120)
                            .cornerRadius(8)
                    }
                    
                    // Status message
                    if let detected = underlinesDetected {
                        HStack {
                            Image(systemName: detected ? "checkmark.circle.fill" : "info.circle.fill")
                                .foregroundColor(detected ? .green : .orange)
                            
                            Text(detected ? "Underlined text detected" : "No underlines detected - showing all text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Retake button
                    Button {
                        resetCameraCapture()
                    } label: {
                        Label("Capture Again", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            } header: {
                Text("Captured Image")
            }
        }
    }
    
    // MARK: - Text Input Section
    
    @ViewBuilder
    private var textInputSection: some View {
        // Quote text input
        Section {
            TextField(
                inputMode == .camera ? "Edit extracted text..." : "Enter quote text...",
                text: $quoteText,
                axis: .vertical
            )
            .lineLimit(5...10)
        } header: {
            Text(inputMode == .camera ? "Extracted Quote" : "Quote")
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
        underlinesDetected = nil
        
        Task {
            do {
                let result = try await ocrService.extractUnderlinedText(from: image)
                
                await MainActor.run {
                    quoteText = result.text
                    underlinesDetected = result.underlinesDetected
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    /// Resets the camera capture to allow retaking
    private func resetCameraCapture() {
        selectedImage = nil
        quoteText = ""
        underlinesDetected = nil
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
