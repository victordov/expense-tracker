import Vision
import UIKit

class OCRService: ObservableObject {
    static let shared = OCRService()
    
    private init() {}
    
    func processReceiptImage(_ image: UIImage) async -> Receipt {
        guard let cgImage = image.cgImage else {
            return Receipt()
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("OCR Error: \(error)")
                    continuation.resume(returning: Receipt())
                    return
                }
                
                let receipt = self.parseReceiptFromVisionResults(request.results)
                continuation.resume(returning: receipt)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error)")
                continuation.resume(returning: Receipt())
            }
        }
    }
    
    private func parseReceiptFromVisionResults(_ results: [Any]?) -> Receipt {
        guard let observations = results as? [VNRecognizedTextObservation] else {
            return Receipt()
        }
        
        var allText: [String] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            allText.append(topCandidate.string)
        }
        
        return parseReceiptText(allText)
    }
    
    private func parseReceiptText(_ textLines: [String]) -> Receipt {
        var storeName = ""
        var date = Date()
        var lineItems: [LineItem] = []
        var totalAmount = 0.0
        
        // Find store name (usually first non-empty line)
        if let firstLine = textLines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            storeName = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Find date
        date = extractDate(from: textLines) ?? Date()
        
        // Find total amount
        totalAmount = extractTotal(from: textLines)
        
        // Extract line items
        lineItems = extractLineItems(from: textLines)
        
        return Receipt(
            storeName: storeName,
            date: date,
            lineItems: lineItems,
            totalAmount: totalAmount
        )
    }
    
    private func extractDate(from lines: [String]) -> Date? {
        let dateFormatter = DateFormatter()
        let dateFormats = [
            "MM/dd/yyyy",
            "M/d/yyyy",
            "MM-dd-yyyy",
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "MMM dd, yyyy"
        ]
        
        for line in lines {
            for format in dateFormats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: line.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return date
                }
                
                // Try to find date pattern within the line
                let words = line.components(separatedBy: .whitespacesAndNewlines)
                for word in words {
                    if let date = dateFormatter.date(from: word) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractTotal(from lines: [String]) -> Double {
        let totalPatterns = [
            "total",
            "amount",
            "sum",
            "balance"
        ]
        
        for line in lines.reversed() { // Start from bottom
            let lowercaseLine = line.lowercased()
            
            for pattern in totalPatterns {
                if lowercaseLine.contains(pattern) {
                    if let amount = extractPriceFromString(line) {
                        return amount
                    }
                }
            }
        }
        
        // If no total found, try to find the largest price
        var maxPrice = 0.0
        for line in lines {
            if let price = extractPriceFromString(line) {
                maxPrice = max(maxPrice, price)
            }
        }
        
        return maxPrice
    }
    
    private func extractLineItems(from lines: [String]) -> [LineItem] {
        var items: [LineItem] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip short lines or lines that look like headers/footers
            if trimmedLine.count < 3 || 
               trimmedLine.lowercased().contains("total") ||
               trimmedLine.lowercased().contains("tax") ||
               trimmedLine.lowercased().contains("subtotal") {
                continue
            }
            
            // Look for lines with prices
            if let price = extractPriceFromString(trimmedLine) {
                let itemName = extractItemName(from: trimmedLine)
                let quantity = extractQuantity(from: trimmedLine)
                
                if !itemName.isEmpty {
                    let lineItem = LineItem(
                        name: itemName,
                        quantity: quantity,
                        unitPrice: price / Double(quantity),
                        isSelected: true
                    )
                    items.append(lineItem)
                }
            }
        }
        
        return items
    }
    
    private func extractPriceFromString(_ string: String) -> Double? {
        // Pattern to match prices like $12.34, 12.34, $12, etc.
        let pricePattern = #"[\$]?(\d+\.?\d*)"#
        
        let regex = try? NSRegularExpression(pattern: pricePattern)
        let range = NSRange(location: 0, length: string.utf16.count)
        
        let matches = regex?.matches(in: string, range: range) ?? []
        
        for match in matches.reversed() { // Get the last price in the line
            if let range = Range(match.range(at: 1), in: string) {
                let priceString = String(string[range])
                return Double(priceString)
            }
        }
        
        return nil
    }
    
    private func extractItemName(from string: String) -> String {
        // Remove price and quantity patterns to get item name
        var cleanString = string
        
        // Remove price patterns
        cleanString = cleanString.replacingOccurrences(of: #"[\$]?(\d+\.?\d*)"#, with: "", options: .regularExpression)
        
        // Remove common quantity patterns
        cleanString = cleanString.replacingOccurrences(of: #"\d+\s*x\s*"#, with: "", options: .regularExpression)
        cleanString = cleanString.replacingOccurrences(of: #"\s*@\s*"#, with: "", options: .regularExpression)
        
        return cleanString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractQuantity(from string: String) -> Int {
        // Look for quantity patterns like "2x", "3 x", etc.
        let quantityPattern = #"(\d+)\s*x"#
        
        let regex = try? NSRegularExpression(pattern: quantityPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: string.utf16.count)
        
        if let match = regex?.firstMatch(in: string, range: range),
           let range = Range(match.range(at: 1), in: string) {
            let quantityString = String(string[range])
            return Int(quantityString) ?? 1
        }
        
        return 1
    }
}
