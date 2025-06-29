import Foundation
import GoogleSignIn
import GoogleAPIClientForREST

class GoogleDriveService: ObservableObject {
    static let shared = GoogleDriveService()

    @Published var isAuthenticated = false
    @Published var userEmail: String?

    private let driveService = GTLRDriveService()
    // Replace with your actual OAuth client ID
    private let clientID = "YOUR_CLIENT_ID_HERE"
    
    private init() {}
    
    // MARK: - Authentication
    
    func authenticate() {
        guard let rootScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = rootScene.windows.first?.rootViewController else {
            print("Unable to obtain root view controller for Google Sign-In")
            return
        }

        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { signInResult, error in
            if let error = error {
                print("Google Drive authentication failed: \(error.localizedDescription)")
                return
            }
            guard let user = signInResult?.user else { return }

            self.isAuthenticated = true
            self.userEmail = user.profile?.email
            self.driveService.authorizer = user.fetcherAuthorizer
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isAuthenticated = false
        userEmail = nil
        driveService.authorizer = nil
    }
    
    // MARK: - Receipt Sync
    
    func syncReceipt(_ receipt: Receipt) {
        guard isAuthenticated else {
            print("User not authenticated with Google Drive")
            return
        }

        let csvData = CSVExporter.shared.generateCSVContent(from: [receipt]).data(using: .utf8) ?? Data()

        uploadFile(data: csvData,
                   fileName: "Receipt_\(Int(Date().timeIntervalSince1970)).csv",
                   mimeType: "text/csv")
    }
    
    func syncAllReceipts(_ receipts: [Receipt]) {
        guard isAuthenticated else {
            print("User not authenticated with Google Drive")
            return
        }

        let csvData = CSVExporter.shared.generateCSVContent(from: receipts).data(using: .utf8) ?? Data()

        uploadFile(data: csvData,
                   fileName: "ReceiptWise_Expenses.csv",
                   mimeType: "text/csv")
    }
    
    // MARK: - File Management
    
    private func uploadFile(data: Data, fileName: String, mimeType: String) {
        let file = GTLRDrive_File()
        file.name = fileName

        let uploadParams = GTLRUploadParameters(data: data, mimeType: mimeType)
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file,
                                                    uploadParameters: uploadParams)

        driveService.executeQuery(query) { _, _, error in
            if let error = error {
                print("Failed to upload file to Google Drive: \(error.localizedDescription)")
            } else {
                print("File uploaded to Google Drive successfully")
            }
        }
    }
    
    // MARK: - Error Handling
    
    enum GoogleDriveError: Error {
        case notAuthenticated
        case networkError
        case fileNotFound
        case uploadFailed
        
        var localizedDescription: String {
            switch self {
            case .notAuthenticated:
                return "User is not authenticated with Google Drive"
            case .networkError:
                return "Network error occurred while syncing to Google Drive"
            case .fileNotFound:
                return "Master CSV file not found in Google Drive"
            case .uploadFailed:
                return "Failed to upload file to Google Drive"
            }
        }
    }
}

// MARK: - Settings View (for Google Drive integration)

import SwiftUI

struct GoogleDriveSettingsView: View {
    @StateObject private var googleDriveService = GoogleDriveService.shared
    
    var body: some View {
        Section(header: Text("Google Drive Sync")) {
            if googleDriveService.isAuthenticated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("Connected")
                            .font(.headline)
                        
                        if let email = googleDriveService.userEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Sign Out") {
                        googleDriveService.signOut()
                    }
                    .foregroundColor(.red)
                }
            } else {
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.red)
                    
                    Text("Not Connected")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Connect") {
                        googleDriveService.authenticate()
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Text("Automatically sync your receipts to Google Drive for backup and easy access from other devices.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
