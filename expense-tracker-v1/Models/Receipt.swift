import Foundation

struct Receipt: Identifiable, Codable {
    var id = UUID()
    var storeName: String
    var date: Date
    var lineItems: [LineItem]
    var totalAmount: Double
    
    init(id: UUID = UUID(), storeName: String = "", date: Date = Date(), lineItems: [LineItem] = [], totalAmount: Double = 0.0) {
        self.id = id
        self.storeName = storeName
        self.date = date
        self.lineItems = lineItems
        self.totalAmount = totalAmount
    }
    
    var calculatedTotal: Double {
        lineItems.filter { $0.isSelected }.reduce(0) { $0 + $1.totalPrice }
    }
    
    var selectedItems: [LineItem] {
        lineItems.filter { $0.isSelected }
    }
}
