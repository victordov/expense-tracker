import CoreData
import Foundation

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    @Published var receipts: [Receipt] = []
    @Published var clients: [Client] = []
    
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
        fetchClients()
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                fetchReceipts() // Refresh the published receipts array
                fetchClients() // Refresh the published clients array
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
        receiptEntity.clientName = receipt.clientName
        receiptEntity.language = receipt.language.rawValue
        receiptEntity.currency = receipt.currency
        receiptEntity.taxAmount = receipt.taxAmount != nil ? NSNumber(value: receipt.taxAmount!) : nil
        receiptEntity.notes = receipt.notes
        receiptEntity.rawText = receipt.rawText
        
        // Find or create client if clientName exists
        if let clientName = receipt.clientName, !clientName.isEmpty {
            let client = findOrCreateClient(named: clientName)
            receiptEntity.client = client
        }
        
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
                receiptEntity.clientName = receipt.clientName
                receiptEntity.language = receipt.language.rawValue
                receiptEntity.currency = receipt.currency
                receiptEntity.taxAmount = receipt.taxAmount != nil ? NSNumber(value: receipt.taxAmount!) : nil
                receiptEntity.notes = receipt.notes
                receiptEntity.rawText = receipt.rawText
                
                // Update client association
                if let clientName = receipt.clientName, !clientName.isEmpty {
                    let client = findOrCreateClient(named: clientName)
                    receiptEntity.client = client
                } else {
                    receiptEntity.client = nil
                }
                
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
                    totalAmount: entity.totalAmount,
                    clientId: entity.client?.id,
                    clientName: entity.clientName,
                    language: ReceiptLanguage(rawValue: entity.language ?? "en") ?? .english,
                    rawText: entity.rawText ?? [],
                    currency: entity.currency ?? "USD",
                    taxAmount: entity.taxAmount?.doubleValue,
                    notes: entity.notes
                )
            }
        } catch {
            print("Fetch error: \(error)")
            self.receipts = []
        }
    }
    
    // MARK: - Client Management
    
    func saveClient(_ client: Client) {
        let context = container.viewContext
        let clientEntity = ClientEntity(context: context)
        
        clientEntity.id = client.id
        clientEntity.name = client.name
        clientEntity.email = client.email
        clientEntity.phone = client.phone
        clientEntity.address = client.address
        clientEntity.createdDate = client.createdDate
        clientEntity.isActive = client.isActive
        
        save()
    }
    
    func findOrCreateClient(named name: String) -> ClientEntity {
        let context = container.viewContext
        let request: NSFetchRequest<ClientEntity> = ClientEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name LIKE[c] %@", name)
        
        do {
            let results = try context.fetch(request)
            if let existingClient = results.first {
                return existingClient
            }
        } catch {
            print("Error finding client: \(error)")
        }
        
        // Create new client
        let clientEntity = ClientEntity(context: context)
        clientEntity.id = UUID()
        clientEntity.name = name
        clientEntity.createdDate = Date()
        clientEntity.isActive = true
        
        return clientEntity
    }
    
    func fetchClients() {
        let request: NSFetchRequest<ClientEntity> = ClientEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClientEntity.name, ascending: true)]
        
        do {
            let clientEntities = try container.viewContext.fetch(request)
            self.clients = clientEntities.compactMap { entity in
                guard let id = entity.id,
                      let name = entity.name,
                      let createdDate = entity.createdDate else { return nil }
                
                // Get associated receipts
                let clientReceipts = receipts.filter { $0.clientId == id }
                
                return Client(
                    id: id,
                    name: name,
                    email: entity.email,
                    phone: entity.phone,
                    address: entity.address,
                    receipts: clientReceipts,
                    createdDate: createdDate,
                    isActive: entity.isActive
                )
            }
        } catch {
            print("Fetch clients error: \(error)")
            self.clients = []
        }
    }
    
    func deleteClient(_ client: Client) {
        let context = container.viewContext
        let request: NSFetchRequest<ClientEntity> = ClientEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", client.id.uuidString)
        
        do {
            let results = try context.fetch(request)
            if let clientEntity = results.first {
                context.delete(clientEntity)
                save()
            }
        } catch {
            print("Delete client error: \(error)")
        }
    }
}
