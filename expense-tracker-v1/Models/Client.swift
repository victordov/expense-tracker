import Foundation

struct Client: Identifiable, Codable {
    var id = UUID()
    var name: String
    var email: String?
    var phone: String?
    var address: String?
    var receipts: [Receipt]
    var createdDate: Date
    var isActive: Bool
    
    init(id: UUID = UUID(), 
         name: String = "", 
         email: String? = nil, 
         phone: String? = nil, 
         address: String? = nil, 
         receipts: [Receipt] = [], 
         createdDate: Date = Date(), 
         isActive: Bool = true) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.address = address
        self.receipts = receipts
        self.createdDate = createdDate
        self.isActive = isActive
    }
    
    var totalExpenses: Double {
        receipts.reduce(0) { $0 + $1.totalAmount }
    }
    
    var receiptCount: Int {
        receipts.count
    }
    
    var lastReceiptDate: Date? {
        receipts.map { $0.date }.max()
    }
    
    // Helper to get receipts within a date range
    func receipts(from startDate: Date, to endDate: Date) -> [Receipt] {
        return receipts.filter { receipt in
            receipt.date >= startDate && receipt.date <= endDate
        }
    }
    
    // Helper to get total expenses within a date range
    func totalExpenses(from startDate: Date, to endDate: Date) -> Double {
        return receipts(from: startDate, to: endDate).reduce(0) { $0 + $1.totalAmount }
    }
}
