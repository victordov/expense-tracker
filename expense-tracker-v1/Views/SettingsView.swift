import SwiftUI

struct SettingsView: View {
    @StateObject private var googleDriveService = GoogleDriveService.shared
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            Form {
                // Google Drive Settings
                GoogleDriveSettingsView()
                
                // App Information
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("About ReceiptWise") {
                        showingAbout = true
                    }
                }
                
                // Support Section
                Section(header: Text("Support")) {
                    Button("Contact Support") {
                        // Open email or support page
                        if let url = URL(string: "mailto:support@receiptwise.com") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                        if let url = URL(string: "https://receiptwise.com/privacy") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "receipt")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("ReceiptWise")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("The most intuitive and effortless way to digitize your purchase history for personal budget tracking.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features:")
                        .font(.headline)
                    
                    FeatureRow(icon: "camera.fill", text: "Smart receipt scanning with OCR")
                    FeatureRow(icon: "pencil", text: "Easy verification and editing")
                    FeatureRow(icon: "externaldrive.fill", text: "Local storage and cloud sync")
                    FeatureRow(icon: "square.and.arrow.up", text: "CSV export functionality")
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}
