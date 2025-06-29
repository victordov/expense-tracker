import SwiftUI

struct ClientGroupedView: View {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedLanguage: ReceiptLanguage? = nil
    @State private var searchText = ""
    @State private var showingAddClient = false
    
    enum TimePeriod: String, CaseIterable {
        case week = "1 Week"
        case month = "1 Month"
        case all = "All Time"
    }
    
    var filteredReceipts: [Receipt] {
        let calendar = Calendar.current
        let now = Date()
        
        var receipts = coreDataManager.receipts
        
        // Filter by time period
        switch selectedPeriod {
        case .week:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            receipts = receipts.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            receipts = receipts.filter { $0.date >= monthAgo }
        case .all:
            break // Show all receipts
        }
        
        // Filter by language
        if let selectedLanguage = selectedLanguage {
            receipts = receipts.filter { $0.language == selectedLanguage }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            receipts = receipts.filter { receipt in
                receipt.storeName.localizedCaseInsensitiveContains(searchText) ||
                receipt.clientName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return receipts
    }
    
    var groupedByClient: [(clientName: String, receipts: [Receipt], totalAmount: Double)] {
        let grouped = Dictionary(grouping: filteredReceipts) { receipt in
            receipt.clientName ?? "Unknown Client"
        }
        
        return grouped.map { (clientName, receipts) in
            let totalAmount = receipts.reduce(0) { $0 + $1.totalAmount }
            return (clientName: clientName, receipts: receipts, totalAmount: totalAmount)
        }.sorted { $0.totalAmount > $1.totalAmount }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filters Section
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search by store or client...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    // Time Period Filter
                    Picker("Time Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Language Filter
                    HStack {
                        Text("Language:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Language", selection: $selectedLanguage) {
                            Text("All Languages").tag(nil as ReceiptLanguage?)
                            ForEach(ReceiptLanguage.allCases, id: \.self) { language in
                                Text(language.displayName).tag(language as ReceiptLanguage?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                // Summary
                if !groupedByClient.isEmpty {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Clients")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(groupedByClient.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Total Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(groupedByClient.reduce(0) { $0 + $1.totalAmount }, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
                
                // Grouped Receipts List
                if groupedByClient.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Clients Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Receipts will be automatically grouped by client when you scan them.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 50)
                } else {
                    List {
                        ForEach(groupedByClient, id: \.clientName) { group in
                            ClientGroupSection(
                                clientName: group.clientName,
                                receipts: group.receipts,
                                totalAmount: group.totalAmount
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle("Clients")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Client") {
                        showingAddClient = true
                    }
                }
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView()
            }
        }
    }
}

struct ClientGroupSection: View {
    let clientName: String
    let receipts: [Receipt]
    let totalAmount: Double
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Client Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(clientName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(receipts.count) receipt\(receipts.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(totalAmount, specifier: "%.2f")")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Receipts List (Expandable)
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(receipts.sorted(by: { $0.date > $1.date })) { receipt in
                        NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                            ReceiptRowView(receipt: receipt, showClient: false)
                        }
                        .padding(.leading, 16)
                    }
                }
                .padding(.top, 8)
                .transition(.slide)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddClientView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var clientName = ""
    @State private var clientEmail = ""
    @State private var clientPhone = ""
    @State private var clientAddress = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Client Information")) {
                    TextField("Client Name", text: $clientName)
                    TextField("Email", text: $clientEmail)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $clientPhone)
                        .keyboardType(.phonePad)
                    TextField("Address", text: $clientAddress, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Add Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Implement client saving
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ClientGroupedView()
}
