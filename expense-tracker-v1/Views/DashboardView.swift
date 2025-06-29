import SwiftUI

struct DashboardView: View {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @State private var selectedPeriod: TimePeriod = .month
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showingCustomDatePicker = false
    
    enum TimePeriod: String, CaseIterable {
        case week = "1 Week"
        case month = "1 Month"
        case custom = "Custom"
    }
    
    var filteredReceipts: [Receipt] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .week:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return coreDataManager.receipts.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return coreDataManager.receipts.filter { $0.date >= monthAgo }
        case .custom:
            return coreDataManager.receipts.filter { 
                $0.date >= customStartDate && $0.date <= customEndDate 
            }
        }
    }
    
    var totalAmount: Double {
        filteredReceipts.reduce(0) { $0 + $1.totalAmount }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Summary Card
                VStack(spacing: 12) {
                    Text("Total Expenses")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("$\(totalAmount, specifier: "%.2f")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("\(filteredReceipts.count) receipts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Period Filter
                VStack(alignment: .leading) {
                    Text("Time Period")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if selectedPeriod == .custom {
                        Button("Select Custom Date Range") {
                            showingCustomDatePicker = true
                        }
                        .padding(.horizontal)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.vertical)
                
                // Receipts List
                if filteredReceipts.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "receipt")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No receipts found")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Start by scanning your first receipt!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredReceipts) { receipt in
                            NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                                ReceiptRowView(receipt: receipt)
                            }
                        }
                        .onDelete(perform: deleteReceipts)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Expense Tracker")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingCustomDatePicker) {
            CustomDateRangeView(
                startDate: $customStartDate,
                endDate: $customEndDate,
                isPresented: $showingCustomDatePicker
            )
        }
        .onAppear {
            coreDataManager.fetchReceipts()
        }
    }
    
    private func deleteReceipts(offsets: IndexSet) {
        for index in offsets {
            let receipt = filteredReceipts[index]
            coreDataManager.deleteReceipt(receipt)
        }
    }
}

struct CustomDateRangeView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section("Start Date") {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                }
                
                Section("End Date") {
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Custom Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Done") {
                    isPresented = false
                }
            )
        }
    }
}

#Preview {
    DashboardView()
}
