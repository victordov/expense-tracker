import Foundation
import Vision
import UIKit

class OCRService: ObservableObject {
    static let shared = OCRService()

    // Using existing language patterns for extraction
    private let romanianPatterns = [
        "total": ["total", "suma", "valoare", "plata"],
        "client": ["client", "către", "pentru", "nume client", "facturare"],
        "tax": ["tva", "taxă", "impozit"]
    ]
    private let englishPatterns = [
        "total": ["total", "amount", "sum", "balance", "due"],
        "client": ["client", "customer", "bill to", "to:", "for:"],
        "tax": ["tax", "vat", "gst"]
    ]

    private init() {}

    /// Main entry point for processing an image.
    func processReceiptImage(_ image: UIImage, expectedLanguage: ReceiptLanguage = .english) async -> Receipt {
        guard let cgImage = image.cgImage else {
            print("Error: Could not create CGImage.")
            return Receipt()
        }

        do {
            let lines = try await recognizeText(in: cgImage, expectedLanguage: expectedLanguage)
            return parseReceiptText(lines, expectedLanguage: expectedLanguage)
        } catch {
            print("An error occurred during OCR processing: \(error.localizedDescription)")
            return Receipt()
        }
    }

    /// Performs Vision text recognition and returns the recognized lines.
    private func recognizeText(in cgImage: CGImage, expectedLanguage: ReceiptLanguage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    let err = NSError(domain: "OCRServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text observations found."])
                    continuation.resume(throwing: err)
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            switch expectedLanguage {
            case .romanian:
                request.recognitionLanguages = ["ro-RO", "en-US"]
            case .english:
                request.recognitionLanguages = ["en-US"]
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Converts raw lines into a structured `Receipt`.
    private func parseReceiptText(_ lines: [String], expectedLanguage: ReceiptLanguage) -> Receipt {
        let language = detectLanguage(from: lines) ?? expectedLanguage
        let storeName = extractStoreName(from: lines)
        let totalAmount = extractTotal(from: lines, language: language)
        let lineItems = extractLineItems(from: lines, totalAmount: totalAmount)
        let date = extractDate(from: lines)
        let clientName = extractClientName(from: lines, language: language)
        let currency = detectCurrency(from: lines)
        let taxAmount = extractTax(from: lines, language: language)

        return Receipt(
            storeName: storeName ?? "",
            date: date ?? Date(),
            lineItems: lineItems,
            totalAmount: totalAmount ?? 0.0,
            clientName: clientName,
            language: language,
            rawText: lines,
            currency: currency,
            taxAmount: taxAmount
        )
    }

    // MARK: - Extraction helpers
    private func extractStoreName(from lines: [String]) -> String? {
        let genericHeaders = ["contul", "clientului", "hygge srl", "whisky club srl", "tax id", "c.f.", "s.r.l"]
        return lines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return false }
            return !genericHeaders.contains(where: { trimmed.localizedCaseInsensitiveContains($0) })
        }?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Attempts to parse each receipt line into a `LineItem`, supporting multi-line names.
    private func extractLineItems(from lines: [String], totalAmount: Double?) -> [LineItem] {
        var items: [LineItem] = []
        var pendingNameParts: [String] = []

        let headers = ["denumire", "cant", "suma", "descriere", "description"]
        let skips = ["client", "total", "tax", "tva", "subtotal", "bon fiscal", "multumim"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if headers.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) { continue }
            if skips.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) { continue }

            if let (name, quantity, price) = parseItemLine(trimmed) {
                if let total = totalAmount, abs(price - total) < 0.01 { continue }
                let fullName = (pendingNameParts + [name]).joined(separator: " ")
                let item = LineItem(name: fullName, quantity: quantity, unitPrice: price / Double(quantity), isSelected: true)
                items.append(item)
                pendingNameParts.removeAll()
            } else if extractPriceFromString(trimmed) == nil {
                pendingNameParts.append(trimmed)
            }
        }

        return items
    }

    /// Parses a single line of text into item components if possible.
    private func parseItemLine(_ line: String) -> (name: String, quantity: Int, price: Double)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if let match = trimmed.firstMatch(of: #/^\s*(\d+)\s*(?:x|X)?\s*(.*?)\s+([\d,.]+)\s*$/#) {
            let qty = Int(match.1) ?? 1
            let name = String(match.2)
            if let price = parsePriceString(String(match.3)) { return (name, qty, price) }
        }

        if let match = trimmed.firstMatch(of: #/^\s*(.*?)\s+(\d+)\s*(?:x|X)\s*([\d,.]+)\s*$/#) {
            let name = String(match.1)
            let qty = Int(match.2) ?? 1
            if let price = parsePriceString(String(match.3)) { return (name, qty, price) }
        }

        if let match = trimmed.firstMatch(of: #/^\s*(.*?)\s+([\d,.]+)\s*$/#) {
            let name = String(match.1)
            if let price = parsePriceString(String(match.2)) { return (name, 1, price) }
        }

        return nil
    }

    /// Remove extraneous characters from an item name.
    private func cleanItemName(_ name: String) -> String? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if cleaned.isEmpty || Double(cleaned) != nil || cleaned.count < 2 { return nil }
        return cleaned
    }

    private func extractTotal(from lines: [String], language: ReceiptLanguage) -> Double? {
        let patterns = language == .romanian ? romanianPatterns["total"]! : englishPatterns["total"]!
        for line in lines.reversed() {
            if patterns.contains(where: { line.localizedCaseInsensitiveContains($0) }) {
                if let price = extractPriceFromString(line) { return price }
            }
        }
        return lines.compactMap({ extractPriceFromString($0) }).max()
    }

    private func extractClientName(from lines: [String], language: ReceiptLanguage) -> String? {
        let patterns = language == .romanian ? romanianPatterns["client"]! : englishPatterns["client"]!
        for line in lines {
            if patterns.contains(where: { line.localizedCaseInsensitiveContains($0) }) {
                if let name = line.components(separatedBy: ":").last, name.trimmingCharacters(in: .whitespaces).count > 2 {
                    return name.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    private func extractTax(from lines: [String], language: ReceiptLanguage) -> Double? {
        let patterns = language == .romanian ? romanianPatterns["tax"]! : englishPatterns["tax"]!
        for line in lines {
            if patterns.contains(where: { line.localizedCaseInsensitiveContains($0) }) {
                if let price = extractPriceFromString(line) { return price }
            }
        }
        return nil
    }

    private func extractDate(from lines: [String]) -> Date? {
        let dateFormats = ["dd.MM.yyyy", "dd/MM/yyyy", "MM/dd/yyyy", "yyyy-MM-dd"]
        let formatter = DateFormatter()
        for line in lines {
            let potential = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if potential.filter({ $0 == "." || $0 == "/" || $0 == "-" }).count < 2 { continue }
            for format in dateFormats {
                formatter.dateFormat = format
                if let date = formatter.date(from: potential) { return date }
            }
        }
        return nil
    }

    private func detectLanguage(from lines: [String]) -> ReceiptLanguage? {
        let romanianKeywords = ["lei", "tva", "factura", "chitanță", "către", "suma"]
        let englishKeywords = ["vat", "tax", "invoice", "receipt", "customer", "amount"]
        var ro = 0
        var en = 0
        for line in lines {
            let lower = line.lowercased()
            if romanianKeywords.contains(where: lower.contains) { ro += 1 }
            if englishKeywords.contains(where: lower.contains) { en += 1 }
        }
        if ro > en { return .romanian }
        if en > ro { return .english }
        return nil
    }

    private func detectCurrency(from lines: [String]) -> String {
        let text = lines.joined(separator: " ").lowercased()
        if text.contains("ron") || text.contains("lei") { return "RON" }
        if text.contains("eur") || text.contains("€") { return "EUR" }
        if text.contains("usd") || text.contains("$") { return "USD" }
        return "RON"
    }

    private func parsePriceString(_ priceStr: String) -> Double? {
        let cleaned = priceStr.replacingOccurrences(of: "[^0-9,.-]", with: "", options: .regularExpression)
        let normalized = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func extractPriceFromString(_ string: String) -> Double? {
        guard let match = string.matches(of: #/([\d,.]+)\s*(?:[A-Za-z]{2,3})?\s*$/#).last else { return nil }
        return parsePriceString(String(match.output.1))
    }
}
