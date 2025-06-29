import Vision
import UIKit

class OCRService: ObservableObject {
    static let shared = OCRService()
    
    private init() {}
    
    // Romanian patterns for receipt parsing
    private let romanianPatterns = [
        "total": ["total", "suma", "valoare", "plata"],
        "date": ["data", "dată", "date"],
        "client": ["client", "către", "pentru", "nume client", "facturare"],
        "quantity": ["cant", "cantitate", "buc", "bucăți", "pc", "pcs"],
        "price": ["preț", "pret", "valoare", "cost"]
    ]
    
    // English patterns for receipt parsing
    private let englishPatterns = [
        "total": ["total", "amount", "sum", "balance", "due"],
        "date": ["date", "time"],
        "client": ["client", "customer", "bill to", "to:", "for:"],
        "quantity": ["qty", "quantity", "pcs", "pieces"],
        "price": ["price", "amount", "cost"]
    ]
    
    func processReceiptImage(_ image: UIImage, expectedLanguage: ReceiptLanguage = .english) async -> Receipt {
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
                
                let receipt = self.parseReceiptFromVisionResults(request.results, expectedLanguage: expectedLanguage)
                continuation.resume(returning: receipt)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            // Set language for better OCR accuracy
            switch expectedLanguage {
            case .romanian:
                request.recognitionLanguages = ["ro", "en"]
            case .english:
                request.recognitionLanguages = ["en"]
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error)")
                continuation.resume(returning: Receipt())
            }
        }
    }
    
    private func parseReceiptFromVisionResults(_ results: [Any]?, expectedLanguage: ReceiptLanguage = .english) -> Receipt {
        guard let observations = results as? [VNRecognizedTextObservation] else {
            return Receipt()
        }
        
        var allText: [String] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            allText.append(topCandidate.string)
        }
        
        return parseReceiptText(allText, expectedLanguage: expectedLanguage)
    }
    
    private func parseReceiptText(_ textLines: [String], expectedLanguage: ReceiptLanguage = .english) -> Receipt {
        var storeName = ""
        var date = Date()
        var lineItems: [LineItem] = []
        var totalAmount = 0.0
        var clientName: String?
        var detectedLanguage = expectedLanguage
        var currency = "USD"
        var taxAmount: Double?
        
        // Auto-detect language based on common words
        detectedLanguage = detectLanguage(from: textLines) ?? expectedLanguage
        
        // Detect currency
        currency = detectCurrency(from: textLines)
        
        // Find store name (usually first non-empty line)
        if let firstLine = textLines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            storeName = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Find client name
        clientName = extractClientName(from: textLines, language: detectedLanguage)
        
        // Find date
        date = extractDate(from: textLines, language: detectedLanguage) ?? Date()
        
        // Find total amount
        totalAmount = extractTotal(from: textLines, language: detectedLanguage)
        
        // Find tax amount
        taxAmount = extractTax(from: textLines, language: detectedLanguage)
        
        // Extract line items
        lineItems = extractLineItems(from: textLines, language: detectedLanguage)
        
        return Receipt(
            storeName: storeName,
            date: date,
            lineItems: lineItems,
            totalAmount: totalAmount,
            clientName: clientName,
            language: detectedLanguage,
            rawText: textLines,
            currency: currency,
            taxAmount: taxAmount
        )
    }
    
    private func detectLanguage(from lines: [String]) -> ReceiptLanguage? {
        let romanianKeywords = ["lei", "ron", "tva", "factura", "chitanță", "către", "suma", "dată", "cantitate", "preț"]
        let englishKeywords = ["total", "amount", "receipt", "date", "qty", "price", "customer"]
        
        var romanianCount = 0
        var englishCount = 0
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            
            for keyword in romanianKeywords {
                if lowercaseLine.contains(keyword) {
                    romanianCount += 1
                }
            }
            
            for keyword in englishKeywords {
                if lowercaseLine.contains(keyword) {
                    englishCount += 1
                }
            }
        }
        
        if romanianCount > englishCount {
            return .romanian
        } else if englishCount > romanianCount {
            return .english
        }
        
        return nil // Unable to determine
    }
    
    private func detectCurrency(from lines: [String]) -> String {
        let currencyPatterns = [
            ("RON", ["ron", "lei"]),
            ("EUR", ["eur", "euro", "€"]),
            ("USD", ["usd", "dollar", "$"])
        ]
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            for (currency, patterns) in currencyPatterns {
                for pattern in patterns {
                    if lowercaseLine.contains(pattern) {
                        return currency
                    }
                }
            }
        }
        
        return "USD" // Default
    }
    
    private func extractClientName(from lines: [String], language: ReceiptLanguage) -> String? {
        let patterns = language == .romanian ? romanianPatterns["client"]! : englishPatterns["client"]!
        
        for (index, line) in lines.enumerated() {
            let lowercaseLine = line.lowercased()
            
            for pattern in patterns {
                if lowercaseLine.contains(pattern) {
                    // Look for client name in current line after the pattern
                    let components = line.components(separatedBy: ":")
                    if components.count > 1 {
                        let clientName = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !clientName.isEmpty && clientName.count > 2 {
                            return clientName
                        }
                    }
                    
                    // Look for client name in the next line
                    if index + 1 < lines.count {
                        let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !nextLine.isEmpty && nextLine.count > 2 && !containsPrice(nextLine) {
                            return nextLine
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func containsPrice(_ string: String) -> Bool {
        return extractPriceFromString(string) != nil
    }
    
    private func extractTax(from lines: [String], language: ReceiptLanguage) -> Double? {
        let taxPatterns = language == .romanian ? ["tva", "taxă", "impozit"] : ["tax", "vat", "gst"]
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            
            for pattern in taxPatterns {
                if lowercaseLine.contains(pattern) {
                    if let amount = extractPriceFromString(line) {
                        return amount
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractDate(from lines: [String], language: ReceiptLanguage = .english) -> Date? {
        let dateFormatter = DateFormatter()
        var dateFormats = [
            "MM/dd/yyyy",
            "M/d/yyyy",
            "MM-dd-yyyy",
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "MMM dd, yyyy"
        ]
        
        // Add Romanian date formats
        if language == .romanian {
            dateFormats.append(contentsOf: [
                "dd.MM.yyyy",
                "d.M.yyyy",
                "dd-MM-yyyy",
                "d-M-yyyy"
            ])
        }
        
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
    
    private func extractTotal(from lines: [String], language: ReceiptLanguage = .english) -> Double {
        let totalPatterns = language == .romanian ? 
            romanianPatterns["total"]! : englishPatterns["total"]!
        
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
    
    private func extractLineItems(from lines: [String], language: ReceiptLanguage = .english) -> [LineItem] {
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
