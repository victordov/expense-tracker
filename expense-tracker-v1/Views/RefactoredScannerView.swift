import SwiftUI

struct RefactoredScannerView: View {
    @State private var receipt: Receipt?
    @State private var isProcessing = false
    private let sampleImage = UIImage(named: "sample-receipt-2")!

    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: sampleImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .padding()

            Button("Process Image") {
                Task {
                    isProcessing = true
                    receipt = await OCRService.shared.processReceiptImage(sampleImage, expectedLanguage: .romanian)
                    isProcessing = false
                }
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)

            if isProcessing {
                ProgressView("Scanning...")
            }

            if let receipt = receipt {
                ReceiptDetailsView(receipt: receipt)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Refactored OCR")
    }
}

struct ReceiptDetailsView: View {
    let receipt: Receipt

    var body: some View {
        List {
            Section(header: Text("Store Info")) {
                if !receipt.storeName.isEmpty { LabeledContent("Store", value: receipt.storeName) }
                LabeledContent("Date", value: receipt.date.formatted(date: .abbreviated, time: .shortened))
                if let currency = receipt.currency { LabeledContent("Currency", value: currency) }
            }

            Section(header: Text("Items")) {
                ForEach(receipt.lineItems) { item in
                    HStack {
                        Text("\(item.quantity)").foregroundStyle(.secondary)
                        Text(item.name)
                        Spacer()
                        Text(String(format: "%.2f", item.totalPrice))
                    }
                }
            }

            Section(header: Text("Totals")) {
                 if let tax = receipt.taxAmount { LabeledContent("Tax", value: String(format: "%.2f", tax)) }
                 LabeledContent("Grand Total", value: String(format: "%.2f", receipt.totalAmount)).bold()
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    NavigationView {
        RefactoredScannerView()
    }
}
