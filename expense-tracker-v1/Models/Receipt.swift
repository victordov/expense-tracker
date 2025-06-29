import Foundation

enum ReceiptLanguage: String, CaseIterable, Codable {
    case english = "en"
    case romanian = "ro"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .romanian: return "Română"
        }
    }
}

struct Receipt: Identifiable, Codable {
    var id = UUID()
    var storeName: String
    var date: Date
    var lineItems: [LineItem]
    var totalAmount: Double
    var clientId: UUID?
    var clientName: String?
    var language: ReceiptLanguage
    var rawText: [String] // Store original OCR text for debugging
    var currency: String
    var taxAmount: Double?
    var notes: String?
    
    init(id: UUID = UUID(), 
         storeName: String = "", 
         date: Date = Date(), 
         lineItems: [LineItem] = [], 
         totalAmount: Double = 0.0,
         clientId: UUID? = nil,
         clientName: String? = nil,
         language: ReceiptLanguage = .english,
         rawText: [String] = [],
         currency: String = "USD",
         taxAmount: Double? = nil,
         notes: String? = nil) {
        self.id = id
        self.storeName = storeName
        self.date = date
        self.lineItems = lineItems
        self.totalAmount = totalAmount
        self.clientId = clientId
        self.clientName = clientName
        self.language = language
        self.rawText = rawText
        self.currency = currency
        self.taxAmount = taxAmount
        self.notes = notes
    }
    
    var calculatedTotal: Double {
        lineItems.filter { $0.isSelected }.reduce(0) { $0 + $1.totalPrice }
    }
    
    var selectedItems: [LineItem] {
        lineItems.filter { $0.isSelected }
    }
}
