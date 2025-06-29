import Foundation

struct LineItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    var unitPrice: Double
    var isSelected: Bool
    
    init(id: UUID = UUID(), name: String = "", quantity: Int = 1, unitPrice: Double = 0.0, isSelected: Bool = true) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.isSelected = isSelected
    }
    
    var totalPrice: Double {
        Double(quantity) * unitPrice
    }
}
