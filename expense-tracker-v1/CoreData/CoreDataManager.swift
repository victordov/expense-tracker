import CoreData
import Foundation

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error.localizedDescription)")
            }
        }
        return container
    }()
    
    private init() {}
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
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
    
    func fetchReceipts() -> [Receipt] {
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReceiptEntity.date, ascending: false)]
        
        do {
            let receiptEntities = try container.viewContext.fetch(request)
            return receiptEntities.compactMap { entity in
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
            return []
        }
    }
}
