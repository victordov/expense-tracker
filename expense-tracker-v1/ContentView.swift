import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    @AppStorage("hasShownOnboarding") private var hasShownOnboarding = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Camera Tab - Main scanning functionality
            CameraView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Scan")
                }
                .tag(0)
            
            // History Tab - View all receipts
            HistoryView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("History")
                }
                .tag(1)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .onAppear {
            if !hasShownOnboarding {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                hasShownOnboarding = true
                showingOnboarding = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
}
