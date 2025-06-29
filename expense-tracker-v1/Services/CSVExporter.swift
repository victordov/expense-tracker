import Foundation

class CSVExporter: ObservableObject {
    static let shared = CSVExporter()
    
    private init() {}
    
    func exportReceipts(_ receipts: [Receipt]) -> URL? {
        let csvContent = generateCSVContent(from: receipts)
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileName = "ReceiptWise_Expenses_\(Date().timeIntervalSince1970).csv"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV file: \(error)")
            return nil
        }
    }
    
    private func generateCSVContent(from receipts: [Receipt]) -> String {
        var csvContent = "Store Name,Date,Item Name,Quantity,Unit Price,Total Price,Receipt Total\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for receipt in receipts {
            let dateString = dateFormatter.string(from: receipt.date)
            
            if receipt.lineItems.isEmpty {
                // If no items, add a single row with receipt info
                csvContent += "\"\(receipt.storeName)\",\"\(dateString)\",\"\",\"\",\"\",\"\",\"\(receipt.totalAmount)\"\n"
            } else {
                for (index, item) in receipt.lineItems.enumerated() {
                    let receiptTotal = index == 0 ? "\(receipt.totalAmount)" : ""
                    csvContent += "\"\(receipt.storeName)\",\"\(dateString)\",\"\(item.name)\",\"\(item.quantity)\",\"\(item.unitPrice)\",\"\(item.totalPrice)\",\"\(receiptTotal)\"\n"
                }
            }
        }
        
        return csvContent
    }
    
    func generateSummaryCSV(from receipts: [Receipt]) -> String {
        var csvContent = "Store Name,Date,Total Amount,Number of Items\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for receipt in receipts {
            let dateString = dateFormatter.string(from: receipt.date)
            csvContent += "\"\(receipt.storeName)\",\"\(dateString)\",\"\(receipt.totalAmount)\",\"\(receipt.lineItems.count)\"\n"
        }
        
        return csvContent
    }
}
