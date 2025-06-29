import SwiftUI

struct HistoryView: View {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(coreDataManager.receipts) { receipt in
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
                    .disabled(coreDataManager.receipts.isEmpty)
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
        coreDataManager.fetchReceipts()
    }
    
    private func exportToCSV() {
        if let url = CSVExporter.shared.exportReceipts(coreDataManager.receipts) {
            exportURL = url
            showingExportSheet = true
        }
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
