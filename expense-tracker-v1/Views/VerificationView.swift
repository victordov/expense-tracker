import SwiftUI

struct VerificationView: View {
    @State private var receipt: Receipt
    @State private var showingAlert = false
    @State private var alertMessage = ""
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    
    init(receipt: Receipt, onDismiss: @escaping () -> Void) {
        self._receipt = State(initialValue: receipt)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Store Information")) {
                    HStack {
                        Text("Store Name:")
                        TextField("Enter store name", text: $receipt.storeName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack {
                        Text("Servant:")
                        TextField("Enter servant name", text: Binding(
                            get: { receipt.servantName ?? "" },
                            set: { receipt.servantName = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    DatePicker("Date:", selection: $receipt.date, displayedComponents: .date)
                }
                
                Section(header: Text("Items")) {
                    ForEach(receipt.lineItems.indices, id: \.self) { index in
                        LineItemRow(
                            item: $receipt.lineItems[index],
                            onDelete: {
                                receipt.lineItems.remove(at: index)
                            }
                        )
                    }
                    
                    Button("Add Item") {
                        receipt.lineItems.append(LineItem())
                    }
                    .foregroundColor(.blue)
                }
                
                Section(header: Text("Total")) {
                    HStack {
                        Text("Calculated Total:")
                        Spacer()
                        Text("$\(receipt.calculatedTotal, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Verify Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReceipt()
                    }
                    .disabled(receipt.storeName.isEmpty || receipt.selectedItems.isEmpty)
                }
            }
        }
        .alert("Receipt Saved", isPresented: $showingAlert) {
            Button("OK") {
                onDismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveReceipt() {
        CoreDataManager.shared.saveReceipt(receipt)
        
        // Sync to Google Drive (placeholder)
        GoogleDriveService.shared.syncReceipt(receipt)
        
        alertMessage = "Receipt saved successfully!"
        showingAlert = true
    }
}

struct LineItemRow: View {
    @Binding var item: LineItem
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    item.isSelected.toggle()
                }) {
                    Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(item.isSelected ? .blue : .gray)
                }
                
                TextField("Item name", text: $item.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Delete") {
                    onDelete()
                }
                .foregroundColor(.red)
                .font(.caption)
            }
            
            HStack {
                Text("Qty:")
                TextField("1", value: $item.quantity, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                
                Text("Price:")
                TextField("0.00", value: $item.unitPrice, format: .currency(code: "USD"))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                
                Spacer()
                
                Text("Total: $\(item.totalPrice, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(item.isSelected ? 1.0 : 0.6)
        .padding(.vertical, 4)
    }
}

#Preview {
    VerificationView(
        receipt: Receipt(
            storeName: "Sample Store",
            date: Date(),
            lineItems: [
                LineItem(name: "Apple", quantity: 2, unitPrice: 1.50),
                LineItem(name: "Bread", quantity: 1, unitPrice: 2.99)
            ],
            totalAmount: 5.99,
            servantName: "Alice",
            language: .english,
            currency: "USD"
        )
    ) {
        // onDismiss
    }
    .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
}
