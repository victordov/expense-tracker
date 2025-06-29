import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            CameraPhotoView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Scan")
                }
                .tag(1)
        }
    }
}

struct CameraPhotoView: View {
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var showingVerification = false
    @State private var scannedReceipt: Receipt?
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Add New Receipt")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 20) {
                Button(action: {
                    sourceType = .camera
                    showingCamera = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                        Text("Take Photo")
                            .font(.headline)
                    }
                    .frame(width: 200, height: 120)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                
                Button(action: {
                    sourceType = .photoLibrary
                    showingImagePicker = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 50))
                        Text("Choose from Library")
                            .font(.headline)
                    }
                    .frame(width: 200, height: 120)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
            }
            
            if isProcessing {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    
                    Text("Processing Receipt...")
                        .font(.headline)
                        .padding(.top)
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: sourceType, onImagePicked: handleImagePicked)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(onImageCaptured: handleImagePicked)
        }
        .sheet(isPresented: $showingVerification) {
            if let receipt = scannedReceipt {
                VerificationView(receipt: receipt) {
                    showingVerification = false
                    scannedReceipt = nil
                }
            }
        }
    }
    
    private func handleImagePicked(_ image: UIImage) {
        isProcessing = true
        
        Task {
            let receipt = await OCRService.shared.processReceiptImage(image)
            
            await MainActor.run {
                scannedReceipt = receipt
                isProcessing = false
                showingVerification = true
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    MainTabView()
}
