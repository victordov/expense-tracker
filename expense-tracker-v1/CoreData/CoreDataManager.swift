import CoreData
import Foundation

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    @Published var receipts: [Receipt] = []
    
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error.localizedDescription)")
            }
        }
        return container
    }()
    
    private init() {
        fetchReceipts()
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                fetchReceipts() // Refresh the published receipts array
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    func saveReceipt(_ receipt: Receipt) {
        let context = container.viewContext
        let receiptEntity = ReceiptEntity(context: context)
        
        receiptEntity.id = receipt.id
        receiptEntity.storeName = receipt.storeName
        receiptEntity.date = receipt.date
        receiptEntity.totalAmount = receipt.calculatedTotal
        
        // Create line item entities
        for lineItem in receipt.selectedItems {
            let lineItemEntity = LineItemEntity(context: context)
            lineItemEntity.id = lineItem.id
            lineItemEntity.name = lineItem.name
            lineItemEntity.quantity = Int32(lineItem.quantity)
            lineItemEntity.unitPrice = lineItem.unitPrice
            lineItemEntity.receipt = receiptEntity
        }
        
        save()
    }
    
    func updateReceipt(_ receipt: Receipt) {
        let context = container.viewContext
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", receipt.id.uuidString)
        
        do {
            let results = try context.fetch(request)
            if let receiptEntity = results.first {
                // Update receipt properties
                receiptEntity.storeName = receipt.storeName
                receiptEntity.date = receipt.date
                receiptEntity.totalAmount = receipt.totalAmount
                
                // Delete existing line items
                if let existingLineItems = receiptEntity.lineItems as? Set<LineItemEntity> {
                    for lineItem in existingLineItems {
                        context.delete(lineItem)
                    }
                }
                
                // Create new line items
                for lineItem in receipt.lineItems {
                    let lineItemEntity = LineItemEntity(context: context)
                    lineItemEntity.id = lineItem.id
                    lineItemEntity.name = lineItem.name
                    lineItemEntity.quantity = Int32(lineItem.quantity)
                    lineItemEntity.unitPrice = lineItem.unitPrice
                    lineItemEntity.receipt = receiptEntity
                }
                
                save()
            }
        } catch {
            print("Update error: \(error)")
        }
    }
    
    func deleteReceipt(_ receipt: Receipt) {
        let context = container.viewContext
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", receipt.id.uuidString)
        
        do {
            let results = try context.fetch(request)
            if let receiptEntity = results.first {
                context.delete(receiptEntity)
                save()
            }
        } catch {
            print("Delete error: \(error)")
        }
    }
    
    func fetchReceipts() {
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReceiptEntity.date, ascending: false)]
        
        do {
            let receiptEntities = try container.viewContext.fetch(request)
            self.receipts = receiptEntities.compactMap { entity in
                guard let id = entity.id,
                      let storeName = entity.storeName,
                      let date = entity.date else { return nil }
                
                let lineItems: [LineItem]
                if let lineItemSet = entity.lineItems as? Set<LineItemEntity> {
                    lineItems = lineItemSet.compactMap { lineItemEntity in
                        guard let lineItemId = lineItemEntity.id,
                              let name = lineItemEntity.name else { return nil }
                        
                        return LineItem(
                            id: lineItemId,
                            name: name,
                            quantity: Int(lineItemEntity.quantity),
                            unitPrice: lineItemEntity.unitPrice,
                            isSelected: true
                        )
                    }
                } else {
                    lineItems = []
                }
                
                return Receipt(
                    id: id,
                    storeName: storeName,
                    date: date,
                    lineItems: lineItems,
                    totalAmount: entity.totalAmount
                )
            }
        } catch {
            print("Fetch error: \(error)")
            self.receipts = []
        }
    }
}
