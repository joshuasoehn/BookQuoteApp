//
//  UnderlineOCRService.swift
//  BookQuotes
//
//  Service for extracting underlined text from book page images using Claude Vision API.
//  Uses AI to intelligently detect pencil underlines and extract only the marked text.
//

import UIKit
import Foundation

/// Errors that can occur during OCR processing
enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextDetected
    case processingFailed(String)
    case networkError(String)
    case apiKeyMissing
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to process the image. Please try again with a different photo."
        case .noTextDetected:
            return "No text was detected in the image. Please ensure the text is clear and well-lit."
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message). Please check your internet connection."
        case .apiKeyMissing:
            return "API key not configured. Please add your Anthropic API key to Config.plist."
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

/// Result of OCR processing
struct OCRResult {
    /// The extracted text (either underlined only, or all text if no underlines detected)
    let text: String
    /// Whether underlines were detected
    let underlinesDetected: Bool
    /// Total number of text regions found (not used with Claude, kept for compatibility)
    let totalTextRegions: Int
    /// Number of underlined text regions found (not used with Claude, kept for compatibility)
    let underlinedRegions: Int
}

/// Service for extracting underlined text from images using Claude Vision API
actor UnderlineOCRService {
    
    // MARK: - Constants
    
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-20250514"
    private let maxTokens = 2048
    
    /// The prompt sent to Claude to extract underlined text
    private let extractionPrompt = """
        Look at this photo of a book page. Your task is to extract the text corresponding to pencil underlines, but you must always return full sentences.
        
        Instructions:
        1. Identify any text that has a pencil underline drawn beneath it
        2. For each underline, determine the complete sentence(s) that contain that underlined text. A sentence runs from a capital letter (or start of paragraph) to a period, question mark, exclamation mark, or end of paragraph
        3. Return the full sentence(s)—never a fragment. If the underline covers only part of a sentence, extend your selection to include the entire sentence. If it spans multiple sentences, include all of those full sentences
        4. Preserve the original paragraph structure and line breaks
        5. Do not add any commentary, labels, or explanations—just return the raw text
        
        If you cannot find any underlined text in the image, respond with exactly: [NO_UNDERLINES_FOUND]
        
        If you find underlined text, return the full sentence(s) directly without any prefix or formatting.
        """
    
    // MARK: - Public API
    
    /// Extracts underlined text from an image using Claude Vision
    /// - Parameter image: The image containing book text with pencil underlines
    /// - Returns: OCRResult containing the extracted text and metadata
    func extractUnderlinedText(from image: UIImage) async throws -> OCRResult {
        // Get API key
        let apiKey: String
        do {
            apiKey = try Config.anthropicAPIKey()
        } catch {
            throw OCRError.apiKeyMissing
        }
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw OCRError.imageConversionFailed
        }
        let base64Image = imageData.base64EncodedString()
        
        // Build the request
        let request = try buildRequest(apiKey: apiKey, base64Image: base64Image)
        
        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            // Try to parse error message from response
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OCRError.apiError(message)
            }
            throw OCRError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        // Parse the response
        let extractedText = try parseResponse(data)
        
        // Check for no underlines marker
        if extractedText.contains("[NO_UNDERLINES_FOUND]") {
            // No underlines detected - we could optionally do a second call to get all text
            // For now, return empty with flag
            return OCRResult(
                text: "",
                underlinesDetected: false,
                totalTextRegions: 0,
                underlinedRegions: 0
            )
        }
        
        // Successfully extracted underlined text
        return OCRResult(
            text: extractedText.trimmingCharacters(in: .whitespacesAndNewlines),
            underlinesDetected: true,
            totalTextRegions: 1,
            underlinedRegions: 1
        )
    }
    
    // MARK: - Private Methods
    
    /// Builds the HTTP request for the Claude API
    private func buildRequest(apiKey: String, base64Image: String) throws -> URLRequest {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Build the message body with image
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": extractionPrompt
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    /// Parses the Claude API response to extract the text
    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OCRError.processingFailed("Invalid JSON response")
        }
        
        // Navigate to content[0].text
        guard let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw OCRError.processingFailed("Could not parse response content")
        }
        
        return text
    }
}
