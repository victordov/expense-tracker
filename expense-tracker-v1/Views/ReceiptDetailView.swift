import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    
    var body: some View {
        List {
            Section(header: Text("Receipt Information")) {
                HStack {
                    Text("Store:")
                    Spacer()
                    Text(receipt.storeName)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Date:")
                    Spacer()
                    Text(receipt.date, style: .date)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Total Amount:")
                    Spacer()
                    Text("$\(receipt.totalAmount, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            
            Section(header: Text("Items (\(receipt.lineItems.count))")) {
                ForEach(receipt.lineItems) { item in
                    ItemDetailRow(item: item)
                }
            }
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ItemDetailRow: View {
    let item: LineItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .font(.headline)
                
                Spacer()
                
                Text("$\(item.totalPrice, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            HStack {
                Text("Quantity: \(item.quantity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Unit Price: $\(item.unitPrice, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationView {
        ReceiptDetailView(
            receipt: Receipt(
                storeName: "Sample Grocery Store",
                date: Date(),
                lineItems: [
                    LineItem(name: "Organic Apples", quantity: 2, unitPrice: 1.50),
                    LineItem(name: "Whole Wheat Bread", quantity: 1, unitPrice: 2.99),
                    LineItem(name: "Milk 2%", quantity: 1, unitPrice: 3.49)
                ],
                totalAmount: 8.48
            )
        )
    }
}
