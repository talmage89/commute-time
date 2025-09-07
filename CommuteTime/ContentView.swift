import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var locationEngine = LocationEngine.shared
    @StateObject private var tripPairingService = TripPairingService.shared
    @StateObject private var notificationService = NotificationService.shared
    @State private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TripsListView()
            } else {
                PermissionsView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .onAppear {
            checkOnboardingStatus()
            setupServices()
        }
    }
    
    private func checkOnboardingStatus() {
        // Check if user has completed onboarding
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // If not explicitly set, check location permission as fallback
        if !hasCompletedOnboarding {
            let locationStatus = CLLocationManager().authorizationStatus
            hasCompletedOnboarding = locationStatus == .authorizedAlways
        }
    }
    
    private func setupServices() {
        locationEngine.start()
        tripPairingService.start()
        notificationService.setup()
    }
}
