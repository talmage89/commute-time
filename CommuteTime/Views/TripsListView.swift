import SwiftUI
import CoreData

struct TripsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var csvExporter = CSVExporter()
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Trip.endEvent?.timestamp, ascending: false),
            NSSortDescriptor(keyPath: \Trip.startEvent?.timestamp, ascending: false)
        ],
        animation: .default
    )
    private var trips: FetchedResults<Trip>
    
    @FetchRequest(
        entity: Location.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Location.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == true")
    )
    private var locations: FetchedResults<Location>
    
    @State private var showingLocationsModal = false
    @State private var showingExportSheet = false
    @State private var selectedTrip: Trip?
    
    var body: some View {
        NavigationView {
            VStack {
                if trips.isEmpty {
                    emptyStateView
                } else {
                    tripsList
                }
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingLocationsModal = true }) {
                            Label("Locations", systemImage: "location.circle")
                        }
                        
                        Button(action: { showingExportSheet = true }) {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(trips.isEmpty)
                        
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingLocationsModal) {
                LocationsModalView()
            }
            .sheet(isPresented: $showingExportSheet) {
                if let csvData = csvExporter.generateCSV(from: Array(trips)) {
                    ShareSheet(activityItems: [csvData])
                } else {
                    Text("Failed to generate CSV")
                }
            }
            .sheet(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "car.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Trips Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Set up your locations to start tracking commute times automatically.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingLocationsModal = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Locations")
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
    
    private var tripsList: some View {
        List {
            ForEach(trips, id: \.id) { trip in
                TripRowView(trip: trip)
                    .onTapGesture {
                        selectedTrip = trip
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            deleteTrip(trip)
                        }
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func deleteTrip(_ trip: Trip) {
        withAnimation {
            TripPairingService.shared.deleteTrip(trip)
        }
    }
}

struct TripRowView: View {
    let trip: Trip
    
    @FetchRequest
    private var startLocation: FetchedResults<Location>
    
    @FetchRequest
    private var endLocation: FetchedResults<Location>
    
    init(trip: Trip) {
        self.trip = trip
        
        // Fetch start location
        self._startLocation = FetchRequest(
            entity: Location.entity(),
            sortDescriptors: [],
            predicate: NSPredicate(format: "id == %@", trip.startEvent?.locationId as CVarArg? ?? UUID() as CVarArg)
        )
        
        // Fetch end location
        self._endLocation = FetchRequest(
            entity: Location.entity(),
            sortDescriptors: [],
            predicate: NSPredicate(format: "id == %@", trip.endEvent?.locationId as CVarArg? ?? UUID() as CVarArg)
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                tripIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    titleView
                    subtitleView
                }
                
                Spacer()
                
                if trip.isComplete {
                    durationView
                }
            }
            
            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var tripIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 28, height: 28)
            
            Image(systemName: iconName)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private var iconBackgroundColor: Color {
        if trip.isComplete {
            return .green
        } else if trip.startEvent != nil {
            return .orange
        } else {
            return .blue
        }
    }
    
    private var iconName: String {
        if trip.isComplete {
            return "checkmark"
        } else if trip.startEvent != nil {
            return "arrow.right"
        } else {
            return "arrow.down"
        }
    }
    
    private var titleView: some View {
        Group {
            if trip.isComplete {
                if let endLocationName = endLocation.first?.name {
                    Text("To \(endLocationName)")
                        .font(.headline)
                } else {
                    Text("Trip Completed")
                        .font(.headline)
                }
            } else if trip.startEvent != nil {
                if let startLocationName = startLocation.first?.name {
                    Text("Leaving \(startLocationName)…")
                        .font(.headline)
                } else {
                    Text("In Progress…")
                        .font(.headline)
                }
            } else {
                if let endLocationName = endLocation.first?.name {
                    Text("To \(endLocationName) (pending start)")
                        .font(.headline)
                } else {
                    Text("Pending Start")
                        .font(.headline)
                }
            }
        }
    }
    
    private var subtitleView: some View {
        Group {
            if trip.isComplete {
                if let duration = trip.durationSeconds,
                   let endTime = trip.endTime {
                    Text("\(duration.formattedDuration) • \(endTime.dateTimeString())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let startTime = trip.startTime {
                Text("Started \(startTime.relativeDateString())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let endTime = trip.endTime {
                Text("Arrived \(endTime.relativeDateString())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var durationView: some View {
        Group {
            if let duration = trip.durationSeconds {
                VStack(alignment: .trailing) {
                    Text(duration.formattedDuration)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("duration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// ShareSheet for exporting CSV
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TripsListView_Previews: PreviewProvider {
    static var previews: some View {
        TripsListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}