import SwiftUI
import CoreData
import CoreLocation

struct LocationsModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationEngine = LocationEngine.shared
    
    @FetchRequest(
        entity: Location.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Location.name, ascending: true)]
    )
    private var locations: FetchedResults<Location>
    
    @State private var showingAddLocation = false
    @State private var editingLocation: Location?
    
    var activeLocationsCount: Int {
        locations.filter { $0.isActive }.count
    }
    
    var availableSlots: Int {
        max(0, Constants.maxGeofenceCount - activeLocationsCount)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Status header
                statusHeader
                
                // Locations list
                locationsList
            }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddLocation = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(availableSlots <= 0)
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView()
            }
            .sheet(item: $editingLocation) { location in
                EditLocationView(location: location)
            }
        }
    }
    
    private var statusHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(activeLocationsCount) of \(Constants.maxGeofenceCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Active Locations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(availableSlots)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(availableSlots > 0 ? .green : .orange)
                    
                    Text("Slots Available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if availableSlots <= 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Maximum locations reached. Deactivate unused locations to add new ones.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .rounded(radius: 12)
        .padding(.horizontal)
    }
    
    private var locationsList: some View {
        Group {
            if locations.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(locations, id: \.id) { location in
                        LocationRowView(location: location) {
                            editingLocation = location
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                deleteLocation(location)
                            }
                            
                            Button(location.isActive ? "Deactivate" : "Activate") {
                                toggleLocationActive(location)
                            }
                            .tint(location.isActive ? .orange : .green)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "location.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Locations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add your first location to start tracking commute times.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingAddLocation = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Location")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .rounded(radius: 20)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func deleteLocation(_ location: Location) {
        withAnimation {
            locationEngine.unregisterGeofence(for: location)
            viewContext.delete(location)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to delete location: \(error)")
            }
        }
    }
    
    private func toggleLocationActive(_ location: Location) {
        withAnimation {
            location.isActive.toggle()
            
            if location.isActive {
                locationEngine.registerGeofence(for: location)
            } else {
                locationEngine.unregisterGeofence(for: location)
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to toggle location active state: \(error)")
            }
        }
    }
}

struct LocationRowView: View {
    let location: Location
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(location.isActive ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name ?? "Unknown")
                    .font(.headline)
                
                Text("\(Int(location.radiusMeters))m radius")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .opacity(location.isActive ? 1.0 : 0.6)
    }
}

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationEngine = LocationEngine.shared
    @StateObject private var locationManager = LocationManager()
    
    @State private var name = ""
    @State private var radius = Constants.defaultGeofenceRadius
    @State private var isGettingLocation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Details")) {
                    TextField("Name", text: $name)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(radius)) meters")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $radius, in: Constants.minGeofenceRadius...Constants.maxGeofenceRadius, step: 25)
                    }
                }
                
                Section(header: Text("Current Location")) {
                    if let location = locationManager.currentLocation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latitude: \(location.coordinate.latitude, specifier: "%.6f")")
                                .font(.caption)
                            Text("Longitude: \(location.coordinate.longitude, specifier: "%.6f")")
                                .font(.caption)
                            Text("Accuracy: ±\(Int(location.horizontalAccuracy))m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            if isGettingLocation {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isGettingLocation ? "Getting location..." : "No location available")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(isGettingLocation ? "Cancel" : "Get Location") {
                                if isGettingLocation {
                                    locationManager.stopUpdating()
                                    isGettingLocation = false
                                } else {
                                    getCurrentLocation()
                                }
                            }
                        }
                    }
                }
                
                Section(footer: Text("This location will be used to create a geofence for automatic trip tracking.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveLocation()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            getCurrentLocation()
        }
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        locationManager.currentLocation != nil
    }
    
    private func getCurrentLocation() {
        isGettingLocation = true
        locationManager.requestLocation { success in
            isGettingLocation = false
            if !success {
                errorMessage = "Could not get current location. Please check location permissions."
                showingError = true
            }
        }
    }
    
    private func saveLocation() {
        guard let currentLocation = locationManager.currentLocation else {
            errorMessage = "Please get current location first"
            showingError = true
            return
        }
        
        let location = Location(context: viewContext)
        location.id = UUID()
        location.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        location.latitude = currentLocation.coordinate.latitude
        location.longitude = currentLocation.coordinate.longitude
        location.radiusMeters = radius
        location.isActive = true
        
        do {
            try viewContext.save()
            locationEngine.registerGeofence(for: location)
            dismiss()
        } catch {
            errorMessage = "Failed to save location: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct EditLocationView: View {
    let location: Location
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationEngine = LocationEngine.shared
    
    @State private var name = ""
    @State private var radius = Constants.defaultGeofenceRadius
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Details")) {
                    TextField("Name", text: $name)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(radius)) meters")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $radius, in: Constants.minGeofenceRadius...Constants.maxGeofenceRadius, step: 25)
                    }
                }
                
                Section(header: Text("Coordinates")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latitude: \(location.latitude, specifier: "%.6f")")
                            .font(.caption)
                        Text("Longitude: \(location.longitude, specifier: "%.6f")")
                            .font(.caption)
                    }
                }
                
                Section(footer: Text("To change the location coordinates, you'll need to delete this location and create a new one.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            loadLocationData()
        }
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func loadLocationData() {
        name = location.name ?? ""
        radius = location.radiusMeters
    }
    
    private func saveChanges() {
        location.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If radius changed, update geofence
        if location.radiusMeters != radius {
            location.radiusMeters = radius
            
            if location.isActive {
                locationEngine.unregisterGeofence(for: location)
                locationEngine.registerGeofence(for: location)
            }
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save location changes: \(error)")
        }
    }
}

// Location manager for getting current location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Bool) -> Void)?
    
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            completion(false)
        }
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
        completion?(false)
        completion = nil
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        completion?(true)
        completion = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(false)
        completion = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else {
            completion?(false)
            completion = nil
        }
    }
}

struct LocationsModalView_Previews: PreviewProvider {
    static var previews: some View {
        LocationsModalView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}