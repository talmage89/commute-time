import SwiftUI
import CoreLocation

struct PermissionsView: View {
    @Binding var hasCompletedOnboarding: Bool
    @StateObject private var locationEngine = LocationEngine.shared
    @StateObject private var notificationService = NotificationService.shared
    
    @State private var hasRequestedLocation = false
    @State private var hasRequestedNotifications = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("Welcome to CommuteTime")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Track your commute times automatically using background location monitoring.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Permissions explanation
                VStack(spacing: 24) {
                    PermissionRowView(
                        icon: "location.fill",
                        title: "Location Access (Always)",
                        description: "Required to track arrivals and departures in the background",
                        isGranted: locationEngine.authorizationStatus == .authorizedAlways,
                        isRequested: hasRequestedLocation
                    )
                    
                    PermissionRowView(
                        icon: "bell.fill",
                        title: "Notifications",
                        description: "Get notified when you arrive or leave a location",
                        isGranted: notificationService.authorizationStatus == .authorized,
                        isRequested: hasRequestedNotifications
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if locationEngine.authorizationStatus != .authorizedAlways {
                        Button(action: requestLocationPermission) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Enable Location (Always)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .rounded(radius: 12)
                        }
                        .disabled(hasRequestedLocation && locationEngine.authorizationStatus == .denied)
                    }
                    
                    if notificationService.authorizationStatus != .authorized {
                        Button(action: requestNotificationPermission) {
                            HStack {
                                Image(systemName: "bell.fill")
                                Text("Enable Notifications")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .rounded(radius: 12)
                        }
                        .disabled(hasRequestedNotifications && notificationService.authorizationStatus == .denied)
                    }
                    
                    // Continue button
                    if canContinue {
                        Button(action: continueToApp) {
                            HStack {
                                Text("Continue to App")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .rounded(radius: 12)
                        }
                    } else {
                        Button(action: continueToApp) {
                            Text("Skip for Now")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .rounded(radius: 12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .onAppear {
            checkInitialPermissions()
        }
    }
    
    private var canContinue: Bool {
        locationEngine.authorizationStatus == .authorizedAlways
    }
    
    private func checkInitialPermissions() {
        // Update our state based on current permissions
        hasRequestedLocation = locationEngine.authorizationStatus != .notDetermined
        hasRequestedNotifications = notificationService.authorizationStatus != .notDetermined
    }
    
    private func requestLocationPermission() {
        hasRequestedLocation = true
        locationEngine.requestLocationPermissions()
    }
    
    private func requestNotificationPermission() {
        hasRequestedNotifications = true
        notificationService.requestNotificationPermissions()
    }
    
    private func continueToApp() {
        hasCompletedOnboarding = true
        
        // Save onboarding completion to UserDefaults
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

struct PermissionRowView: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let isRequested: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green : Color.gray.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .foregroundColor(isGranted ? .white : .gray)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    Spacer()
                    
                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isRequested {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .rounded(radius: 12)
    }
}

// Helper extension for rounded corners
extension View {
    func rounded(radius: CGFloat) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView(hasCompletedOnboarding: .constant(false))
    }
}