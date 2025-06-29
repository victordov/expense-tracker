import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @State private var isEditing = false
    @State private var editedStoreName: String = ""
    @State private var editedDate: Date = Date()
    @State private var editedLineItems: [LineItem] = []
    @StateObject private var coreDataManager = CoreDataManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            Section(header: Text("Receipt Information")) {
                if isEditing {
                    VStack(alignment: .leading) {
                        Text("Store Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Store Name", text: $editedStoreName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker("Date", selection: $editedDate, displayedComponents: .date)
                    }
                } else {
                    HStack {
                        Text("Store:")
                        Spacer()
                        Text(receipt.storeName.isEmpty ? "Unknown Store" : receipt.storeName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Date:")
                        Spacer()
                        Text(receipt.date, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Total Amount:")
                    Spacer()
                    Text("$\(isEditing ? editedLineItems.reduce(0) { $0 + ($1.unitPrice * Double($1.quantity)) } : receipt.totalAmount, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            
            Section(header: Text("Items (\(isEditing ? editedLineItems.count : receipt.lineItems.count))")) {
                if isEditing {
                    ForEach(editedLineItems.indices, id: \.self) { index in
                        EditableItemRow(item: $editedLineItems[index])
                    }
                    .onDelete(perform: deleteItems)
                    
                    Button(action: addNewItem) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Item")
                        }
                        .foregroundColor(.blue)
                    }
                } else {
                    ForEach(receipt.lineItems) { item in
                        ItemDetailRow(item: item)
                    }
                }
            }
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            trailing: Button(isEditing ? "Save" : "Edit") {
                if isEditing {
                    saveChanges()
                } else {
                    startEditing()
                }
            }
        )
        .onAppear {
            setupEditingData()
        }
    }
    
    private func setupEditingData() {
        editedStoreName = receipt.storeName
        editedDate = receipt.date
        editedLineItems = receipt.lineItems
    }
    
    private func startEditing() {
        isEditing = true
    }
    
    private func saveChanges() {
        // Update the receipt with edited data
        let updatedReceipt = Receipt(
            id: receipt.id,
            storeName: editedStoreName,
            date: editedDate,
            lineItems: editedLineItems,
            totalAmount: editedLineItems.reduce(0) { $0 + ($1.unitPrice * Double($1.quantity)) }
        )
        
        coreDataManager.updateReceipt(updatedReceipt)
        isEditing = false
    }
    
    private func deleteItems(offsets: IndexSet) {
        editedLineItems.remove(atOffsets: offsets)
    }
    
    private func addNewItem() {
        let newItem = LineItem(
            name: "New Item",
            quantity: 1,
            unitPrice: 0.0,
            isSelected: true
        )
        editedLineItems.append(newItem)
    }
}

struct EditableItemRow: View {
    @Binding var item: LineItem
    
    var body: some View {
        VStack(spacing: 8) {
            TextField("Item Name", text: $item.name)
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Quantity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Qty", value: $item.quantity, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                VStack(alignment: .leading) {
                    Text("Unit Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Price", value: $item.unitPrice, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
            }
            
            HStack {
                Text("Total: $\(item.unitPrice * Double(item.quantity), specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
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
