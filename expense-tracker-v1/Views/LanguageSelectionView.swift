import SwiftUI

struct LanguageSelectionView: View {
    @Binding var selectedLanguage: ReceiptLanguage
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Receipt Language")) {
                    ForEach(ReceiptLanguage.allCases, id: \.self) { language in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.displayName)
                                    .font(.headline)
                                
                                Text(language == .english ? "For English receipts" : "Pentru chitanțe în română")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedLanguage = language
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                
                Section(footer: Text("Selecting the correct language improves OCR accuracy and helps detect client information more reliably.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LanguageSelectionView(selectedLanguage: .constant(.english))
}
