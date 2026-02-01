//
//  UnderlineOCRService.swift
//  BookQuotes
//
//  Service for extracting underlined text from book page images using Vision framework.
//  Detects pencil underlines and extracts only the text above those underlines.
//

import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// Errors that can occur during OCR processing
enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextDetected
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to process the image. Please try again with a different photo."
        case .noTextDetected:
            return "No text was detected in the image. Please ensure the text is clear and well-lit."
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        }
    }
}

/// Result of OCR processing
struct OCRResult {
    /// The extracted text (either underlined only, or all text if no underlines detected)
    let text: String
    /// Whether underlines were detected
    let underlinesDetected: Bool
    /// Total number of text regions found
    let totalTextRegions: Int
    /// Number of underlined text regions found
    let underlinedRegions: Int
}

/// A text observation with its bounding box in image coordinates
private struct TextRegion {
    let text: String
    let boundingBox: CGRect  // Normalized coordinates (0-1), origin at bottom-left
    let confidence: Float
    
    /// Bottom edge of the text (in Vision coordinates where Y increases upward)
    var bottom: CGFloat { boundingBox.minY }
    /// Top edge of the text
    var top: CGFloat { boundingBox.maxY }
    /// Left edge
    var left: CGFloat { boundingBox.minX }
    /// Right edge
    var right: CGFloat { boundingBox.maxX }
    /// Height of the text region
    var height: CGFloat { boundingBox.height }
    /// Width of the text region
    var width: CGFloat { boundingBox.width }
    /// Center X position
    var centerX: CGFloat { boundingBox.midX }
}

/// A detected horizontal line that could be an underline
private struct DetectedLine {
    let y: CGFloat           // Y position (normalized 0-1, Vision coordinates)
    let xStart: CGFloat      // Left edge (normalized 0-1)
    let xEnd: CGFloat        // Right edge (normalized 0-1)
    let avgBrightness: CGFloat  // Average brightness (0-1, lower = darker)
    
    var width: CGFloat { xEnd - xStart }
    var centerX: CGFloat { (xStart + xEnd) / 2 }
}

/// Service for extracting underlined text from images using Vision framework
actor UnderlineOCRService {
    
    private let ciContext = CIContext()
    
    // MARK: - Public API
    
    /// Extracts underlined text from an image
    /// - Parameter image: The image containing book text with pencil underlines
    /// - Returns: OCRResult containing the extracted text and metadata
    func extractUnderlinedText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }
        
        // Run text recognition
        var textRegions = try await recognizeText(in: cgImage)
        
        if textRegions.isEmpty {
            throw OCRError.noTextDetected
        }
        
        // Filter out margin text and fragments
        textRegions = filterMainBodyText(textRegions)
        
        if textRegions.isEmpty {
            throw OCRError.noTextDetected
        }
        
        // Detect pencil underlines
        let detectedLines = detectPencilUnderlines(in: cgImage, textRegions: textRegions)
        
        // Match underlines to text regions
        let underlinedRegions = findUnderlinedText(textRegions: textRegions, lines: detectedLines)
        
        // If we found underlined text, return only that
        if !underlinedRegions.isEmpty {
            // Sort by Y position (top to bottom in reading order)
            let sortedRegions = underlinedRegions.sorted { $0.top > $1.top }
            
            // Join with spaces for same-line continuity, newlines for actual line breaks
            let underlinedText = formatTextRegions(sortedRegions)
            
            return OCRResult(
                text: underlinedText,
                underlinesDetected: true,
                totalTextRegions: textRegions.count,
                underlinedRegions: underlinedRegions.count
            )
        }
        
        // No underlines detected - return all filtered text as fallback
        let sortedRegions = textRegions.sorted { $0.top > $1.top }
        let allText = formatTextRegions(sortedRegions)
        
        return OCRResult(
            text: allText,
            underlinesDetected: false,
            totalTextRegions: textRegions.count,
            underlinedRegions: 0
        )
    }
    
    // MARK: - Text Recognition
    
    private func recognizeText(in cgImage: CGImage) async throws -> [TextRegion] {
        try await withCheckedThrowingContinuation { continuation in
            var textRegions: [TextRegion] = []
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.processingFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first,
                          topCandidate.confidence >= 0.3 else {
                        continue
                    }
                    
                    let region = TextRegion(
                        text: topCandidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: topCandidate.confidence
                    )
                    textRegions.append(region)
                }
                
                continuation.resume(returning: textRegions)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.processingFailed(error.localizedDescription))
            }
        }
    }
    
    // MARK: - Text Filtering
    
    /// Filter out margin text, fragments, and other non-main-body text
    private func filterMainBodyText(_ regions: [TextRegion]) -> [TextRegion] {
        guard !regions.isEmpty else { return [] }
        
        // Find the main text column by analyzing text positions
        // Most book text will be in a central column
        
        // Calculate statistics about text positions
        let leftEdges = regions.map { $0.left }
        let rightEdges = regions.map { $0.right }
        let widths = regions.map { $0.width }
        
        // Find the most common left margin (where main text starts)
        let avgLeft = leftEdges.reduce(0, +) / CGFloat(leftEdges.count)
        let avgRight = rightEdges.reduce(0, +) / CGFloat(rightEdges.count)
        let avgWidth = widths.reduce(0, +) / CGFloat(widths.count)
        
        // Filter regions:
        // 1. Must be reasonably wide (not single words or fragments)
        // 2. Must be in the main text area (not far left margin)
        // 3. Must have reasonable confidence
        
        let filtered = regions.filter { region in
            // Skip very short text (likely margin fragments or page numbers)
            guard region.text.count >= 10 else { return false }
            
            // Skip text that's much narrower than average (likely margin notes)
            guard region.width >= avgWidth * 0.4 else { return false }
            
            // Skip text that starts way before the main column (left margin text)
            // Allow some tolerance for indentation
            guard region.left >= avgLeft - 0.15 else { return false }
            
            // Skip text that's way to the right (potential margin notes)
            guard region.left <= 0.5 else { return false }
            
            // Skip very low confidence text
            guard region.confidence >= 0.5 else { return false }
            
            return true
        }
        
        return filtered
    }
    
    // MARK: - Underline Detection
    
    /// Detect pencil underlines by looking for gray horizontal marks below text
    private func detectPencilUnderlines(in cgImage: CGImage, textRegions: [TextRegion]) -> [DetectedLine] {
        let width = cgImage.width
        let height = cgImage.height
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return []
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else {
            return []
        }
        
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)
        var detectedLines: [DetectedLine] = []
        
        // First, calculate average page brightness to adapt threshold
        var totalBrightness: Int = 0
        let sampleStep = 10
        var sampleCount = 0
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                totalBrightness += Int(pixels[y * width + x])
                sampleCount += 1
            }
        }
        let avgPageBrightness = totalBrightness / max(1, sampleCount)
        
        // Adaptive threshold: anything noticeably darker than the page average
        // For a typical book page (brightness ~200), pencil marks might be ~150-180
        let darkThreshold = UInt8(max(50, min(200, avgPageBrightness - 25)))
        
        // For each text region, look for pencil marks in the zone just below it
        for region in textRegions {
            // Convert Vision coordinates to pixel coordinates
            // Vision: Y=0 at bottom, Y=1 at top
            // CGImage: Y=0 at top, Y=height at bottom
            let textBottomPixel = Int((1.0 - region.bottom) * CGFloat(height))
            let textLeftPixel = Int(region.left * CGFloat(width))
            let textRightPixel = Int(region.right * CGFloat(width))
            let textHeightPixel = Int(region.height * CGFloat(height))
            
            // Expand search zone - underlines can be anywhere from touching the text
            // to about 1/3 of the text height below
            let searchStartY = max(0, textBottomPixel - 2)
            let searchEndY = min(height - 1, textBottomPixel + max(textHeightPixel / 2, 20))
            
            // Search within the text's horizontal bounds (with larger margin)
            let searchLeft = max(0, textLeftPixel - 10)
            let searchRight = min(width - 1, textRightPixel + 10)
            let searchWidth = searchRight - searchLeft
            
            guard searchWidth > 20, searchStartY < searchEndY else { continue }
            
            // For each row in the search zone, look for horizontal dark streaks
            var bestLine: (y: Int, start: Int, length: Int, avgBrightness: Int)? = nil
            
            for y in searchStartY..<searchEndY {
                var runStart: Int? = nil
                var runLength = 0
                var runBrightness: Int = 0
                
                for x in searchLeft...searchRight {
                    let pixel = pixels[y * width + x]
                    
                    // Simple check: is this pixel darker than the page threshold?
                    // But not too dark (which would be printed text)
                    let isDark = pixel < darkThreshold && pixel > 30
                    
                    if isDark {
                        if runStart == nil {
                            runStart = x
                            runLength = 0
                            runBrightness = 0
                        }
                        runLength += 1
                        runBrightness += Int(pixel)
                    } else {
                        // End of dark run - check if it's a valid underline candidate
                        if let start = runStart, runLength >= searchWidth / 3 {
                            let avgBright = runBrightness / runLength
                            // Keep track of the best (longest) line for this text region
                            if bestLine == nil || runLength > bestLine!.length {
                                bestLine = (y, start, runLength, avgBright)
                            }
                        }
                        runStart = nil
                        runLength = 0
                        runBrightness = 0
                    }
                }
                
                // Check end of row
                if let start = runStart, runLength >= searchWidth / 3 {
                    let avgBright = runBrightness / runLength
                    if bestLine == nil || runLength > bestLine!.length {
                        bestLine = (y, start, runLength, avgBright)
                    }
                }
            }
            
            // If we found a good line candidate for this text region, add it
            if let line = bestLine {
                let normalizedY = 1.0 - (CGFloat(line.y) / CGFloat(height))
                let detectedLine = DetectedLine(
                    y: normalizedY,
                    xStart: CGFloat(line.start) / CGFloat(width),
                    xEnd: CGFloat(line.start + line.length) / CGFloat(width),
                    avgBrightness: CGFloat(line.avgBrightness) / 255.0
                )
                detectedLines.append(detectedLine)
            }
        }
        
        // Deduplicate lines at similar positions
        return deduplicateLines(detectedLines)
    }
    
    /// Remove duplicate lines that are at very similar positions
    private func deduplicateLines(_ lines: [DetectedLine]) -> [DetectedLine] {
        var result: [DetectedLine] = []
        
        for line in lines {
            let isDuplicate = result.contains { existing in
                abs(existing.y - line.y) < 0.008 &&  // Within ~1% Y distance
                abs(existing.centerX - line.centerX) < 0.1
            }
            
            if !isDuplicate {
                result.append(line)
            }
        }
        
        return result
    }
    
    // MARK: - Underline Matching
    
    private func findUnderlinedText(textRegions: [TextRegion], lines: [DetectedLine]) -> [TextRegion] {
        var underlinedRegions: [TextRegion] = []
        
        for region in textRegions {
            // Check if any detected line is positioned to be an underline for this text
            for line in lines {
                // Line should be just below the text (in Vision coordinates)
                let verticalGap = region.bottom - line.y
                
                // Gap should be small and positive (line below text)
                guard verticalGap > 0 && verticalGap < 0.025 else { continue }
                
                // Line should overlap horizontally with the text
                let overlapStart = max(region.left, line.xStart)
                let overlapEnd = min(region.right, line.xEnd)
                let overlap = overlapEnd - overlapStart
                
                // Require significant horizontal overlap
                if overlap > region.width * 0.4 {
                    underlinedRegions.append(region)
                    break
                }
            }
        }
        
        return underlinedRegions
    }
    
    // MARK: - Text Formatting
    
    /// Format text regions into readable text, handling line breaks properly
    private func formatTextRegions(_ regions: [TextRegion]) -> String {
        guard !regions.isEmpty else { return "" }
        
        // Group regions by approximate Y position (same line)
        var lines: [[TextRegion]] = []
        var currentLine: [TextRegion] = []
        var lastY: CGFloat = regions[0].top
        
        for region in regions {
            // If Y position is significantly different, start a new line
            if abs(region.top - lastY) > 0.015 {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = [region]
            } else {
                currentLine.append(region)
            }
            lastY = region.top
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        // Sort regions within each line by X position (left to right)
        // Then join with spaces within lines, newlines between lines
        let formattedLines = lines.map { lineRegions in
            lineRegions
                .sorted { $0.left < $1.left }
                .map { $0.text }
                .joined(separator: " ")
        }
        
        return formattedLines.joined(separator: "\n")
    }
}
