import SwiftUI

struct HistoryView: View {
    @State private var receipts: [Receipt] = []
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(receipts) { receipt in
                    NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                        ReceiptRowView(receipt: receipt)
                    }
                }
            }
            .navigationTitle("Receipt History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export CSV") {
                        exportToCSV()
                    }
                    .disabled(receipts.isEmpty)
                }
            }
            .refreshable {
                loadReceipts()
            }
            .onAppear {
                loadReceipts()
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ActivityViewController(activityItems: [url])
                }
            }
        }
    }
    
    private func loadReceipts() {
        receipts = CoreDataManager.shared.fetchReceipts()
    }
    
    private func exportToCSV() {
        if let url = CSVExporter.shared.exportReceipts(receipts) {
            exportURL = url
            showingExportSheet = true
        }
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(receipt.storeName)
                    .font(.headline)
                
                Spacer()
                
                Text("$\(receipt.totalAmount, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            HStack {
                Text(receipt.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(receipt.lineItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    HistoryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
}
