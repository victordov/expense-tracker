import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            // Welcome Page
            OnboardingPageView(
                icon: "receipt",
                title: "Welcome to ReceiptWise",
                description: "The easiest way to track your expenses by simply scanning your receipts.",
                showButton: false
            )
            .tag(0)
            
            // Camera Permission Page
            OnboardingPageView(
                icon: "camera.fill",
                title: "Scan Receipts",
                description: "Use your camera to quickly capture receipt information. We'll extract all the important details automatically.",
                showButton: false
            )
            .tag(1)
            
            // Verification Page
            OnboardingPageView(
                icon: "checkmark.circle.fill",
                title: "Verify & Edit",
                description: "Review the scanned information and make any necessary corrections before saving.",
                showButton: false
            )
            .tag(2)
            
            // Cloud Sync Page
            OnboardingPageView(
                icon: "icloud.fill",
                title: "Sync & Export",
                description: "Automatically sync your data to Google Drive or export to CSV for use in other apps.",
                showButton: true,
                buttonText: "Get Started",
                buttonAction: onComplete
            )
            .tag(3)
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
    }
}

struct OnboardingPageView: View {
    let icon: String
    let title: String
    let description: String
    let showButton: Bool
    var buttonText: String = ""
    var buttonAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Spacer()
            
            if showButton {
                Button(action: {
                    buttonAction?()
                }) {
                    Text(buttonText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            } else {
                Text("Swipe to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 50)
            }
        }
        .padding()
    }
}

#Preview {
    OnboardingView {
        // onComplete
    }
}
