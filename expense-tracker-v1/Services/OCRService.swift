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
    /// - Parameters:
    ///   - image: receipt photo
    ///   - expectedLanguage: hint for OCR
    ///   - useChatGPT: if true, parse using the OpenAI API
    func processReceiptImage(_ image: UIImage, expectedLanguage: ReceiptLanguage = .english, useChatGPT: Bool = false) async -> Receipt {
        guard let cgImage = image.cgImage else {
            print("Error: Could not create CGImage.")
            return Receipt()
        }

        do {
            let lines = try await recognizeText(in: cgImage, expectedLanguage: expectedLanguage)
            if useChatGPT, let gptReceipt = try? await parseWithChatGPT(lines) {
                return gptReceipt
            }
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
        var pendingParts: [String] = []

        let headerKeywords = ["denumire", "cant", "suma", "descriere", "description"]
        let skipKeywords = ["client", "total", "tax", "tva", "subtotal", "bon fiscal", "multumim"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if headerKeywords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) { continue }
            if skipKeywords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) { continue }

            if let (name, quantity, price) = parseItemLine(trimmed) {
                if let total = totalAmount, abs(price - total) < 0.01 { continue }
                let fullName = (pendingParts + [name]).joined(separator: " ")
                let item = LineItem(name: fullName, quantity: quantity, unitPrice: price / Double(quantity), isSelected: true)
                items.append(item)
                pendingParts.removeAll()
            } else if extractPriceFromString(trimmed) == nil {
                pendingParts.append(trimmed)
            }
        }

        return items
    }

    /// Parses a single line of text into item components if possible.
    private func parseItemLine(_ line: String) -> (name: String, quantity: Int, price: Double)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Patterns attempt to locate quantity, name and price in common configurations.
        // 1. "2 x Apples 9.99" or "2 Apples 9,99 RON"
        if let match = trimmed.firstMatch(of: #/^\s*(\d+)\s*(?:x|X)?\s*(.*?)\s+(\d+[.,]\d+)\s*(?:[A-Za-z]{2,3})?\s*$/#) {
            let qty = Int(match.1) ?? 1
            let name = String(match.2)
            if let price = parsePriceString(String(match.3)) { return (name, qty, price) }
        }

        // 2. "Apples 2 x 9.99" or "Apples 2x9,99"
        if let match = trimmed.firstMatch(of: #/^\s*(.*?)\s+(\d+)\s*(?:x|X)\s*(\d+[.,]\d+)\s*(?:[A-Za-z]{2,3})?\s*$/#) {
            let name = String(match.1)
            let qty = Int(match.2) ?? 1
            if let price = parsePriceString(String(match.3)) { return (name, qty, price) }
        }

        // 3. "Apples 9.99" - assume quantity 1
        if let match = trimmed.firstMatch(of: #/^\s*(.*?)\s+(\d+[.,]\d+)\s*(?:[A-Za-z]{2,3})?\s*$/#) {
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
        var cleaned = priceStr.replacingOccurrences(of: "[^0-9.,-]", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        if cleaned.filter({ $0 == "." }).count > 1, let lastDot = cleaned.lastIndex(of: ".") {
            let before = cleaned[..<lastDot].replacingOccurrences(of: ".", with: "")
            let after = cleaned[lastDot...]
            cleaned = before + after
        }
        return Double(cleaned)
    }

    private func extractPriceFromString(_ string: String) -> Double? {
        // Grab the last number in the line which usually represents the price
        guard let match = string.matches(of: #/([0-9]+(?:[.,][0-9]{1,2})?)(?!.*[0-9])/#).last else { return nil }
        return parsePriceString(String(match.output.1))
    }

    // MARK: - ChatGPT Parsing

    private func parseWithChatGPT(_ lines: [String]) async throws -> Receipt? {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            return nil
        }

        let prompt = """
        You are an OCR post-processor. Extract the store name, servant name, date, all line items with quantity and unit price, and the total amount from the following receipt text. Respond only in JSON with fields storeName, servantName, date (yyyy-MM-dd), items (name, quantity, unitPrice), totalAmount.

        Receipt text:
        \(lines.joined(separator: "\n"))
        """

        struct ChatMessage: Codable { let role: String; let content: String }
        struct ChatRequest: Codable { let model: String; let messages: [ChatMessage] }
        struct ChatChoice: Codable { let message: ChatMessage }
        struct ChatResponse: Codable { let choices: [ChatChoice] }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(model: "gpt-3.5-turbo", messages: [
            .init(role: "system", content: "You output JSON only."),
            .init(role: "user", content: prompt)
        ])
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let message = response.choices.first?.message.content,
              let jsonData = message.data(using: .utf8) else { return nil }

        struct GPTLineItem: Codable { var name: String; var quantity: Int; var unitPrice: Double }
        struct GPTReturn: Codable { var storeName: String?; var servantName: String?; var date: String?; var items: [GPTLineItem]; var totalAmount: Double? }

        let decoded = try JSONDecoder().decode(GPTReturn.self, from: jsonData)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let parsedDate = decoded.date.flatMap { formatter.date(from: $0) }
        let items = decoded.items.map { LineItem(name: $0.name, quantity: $0.quantity, unitPrice: $0.unitPrice, isSelected: true) }

        return Receipt(
            storeName: decoded.storeName ?? "",
            date: parsedDate ?? Date(),
            lineItems: items,
            totalAmount: decoded.totalAmount ?? 0,
            clientId: nil,
            clientName: nil,
            servantName: decoded.servantName,
            language: .english,
            rawText: lines,
            currency: detectCurrency(from: lines),
            taxAmount: nil
        )
    }
}
