import SwiftUI

struct ReceiptRowView: View {
    let receipt: Receipt
    let showClient: Bool
    
    init(receipt: Receipt, showClient: Bool = true) {
        self.receipt = receipt
        self.showClient = showClient
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.storeName.isEmpty ? "Unknown Store" : receipt.storeName)
                    .font(.headline)
                    .lineLimit(1)
                
                if showClient, let clientName = receipt.clientName {
                    Text(clientName)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text(receipt.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Language indicator
                    Text(receipt.language.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(receipt.language == .romanian ? Color.blue : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                
                Text("\(receipt.lineItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(receipt.totalAmount, specifier: "%.2f") \(receipt.currency)")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let taxAmount = receipt.taxAmount {
                    Text("Tax: \(taxAmount, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ReceiptRowView(
            receipt: Receipt(
                storeName: "Sample Store",
                date: Date(),
                lineItems: [
                    LineItem(name: "Item 1", quantity: 2, unitPrice: 5.99)
                ],
                totalAmount: 11.98,
                clientName: "John Doe",
                language: .romanian,
                currency: "RON"
            ),
            showClient: true
        )
        
        ReceiptRowView(
            receipt: Receipt(
                storeName: "Another Store",
                date: Date(),
                lineItems: [
                    LineItem(name: "Item 2", quantity: 1, unitPrice: 3.49)
                ],
                totalAmount: 3.49,
                language: .english
            ),
            showClient: false
        )
    }
}
