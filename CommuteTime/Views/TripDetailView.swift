import SwiftUI
import CoreData

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false
    @State private var editingStartTime = false
    @State private var editingEndTime = false
    @State private var tempStartTime = Date()
    @State private var tempEndTime = Date()
    
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
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trip status card
                    tripStatusCard
                    
                    // Trip details
                    if trip.startEvent != nil || trip.endEvent != nil {
                        tripDetailsSection
                    }
                    
                    // Duration (if complete)
                    if trip.isComplete {
                        durationSection
                    }
                    
                    // Notes section
                    notesSection
                    
                    // Delete button
                    deleteSection
                }
                .padding()
            }
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .alert("Delete Trip", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteTrip()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the trip and its events. This action cannot be undone.")
            }
        }
        .onAppear {
            loadTripData()
        }
    }
    
    private var tripStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                statusIcon
                
                VStack(alignment: .leading) {
                    statusTitle
                    statusSubtitle
                }
                
                Spacer()
            }
            
            if trip.isComplete {
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Start")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(startLocation.first?.name ?? "Unknown")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("End")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(endLocation.first?.name ?? "Unknown")
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .rounded(radius: 12)
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(trip.isComplete ? Color.green : Color.orange)
                .frame(width: 40, height: 40)
            
            Image(systemName: trip.isComplete ? "checkmark" : "clock")
                .foregroundColor(.white)
                .font(.title3)
        }
    }
    
    private var statusTitle: some View {
        Text(trip.isComplete ? "Completed Trip" : "Pending Trip")
            .font(.headline)
    }
    
    private var statusSubtitle: some View {
        Group {
            if trip.isComplete {
                if let endTime = trip.endTime {
                    Text("Completed \(endTime.relativeDateString())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if trip.startEvent != nil {
                Text("Waiting for arrival")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Waiting for departure")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var tripDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trip Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                if let startEvent = trip.startEvent {
                    EventRowView(
                        title: "Departure",
                        location: startLocation.first?.name ?? "Unknown",
                        time: startEvent.timestamp,
                        source: startEvent.eventSource?.displayName ?? "Unknown",
                        wasEdited: startEvent.wasEdited,
                        isEditing: editingStartTime,
                        tempTime: $tempStartTime,
                        onEditTap: {
                            tempStartTime = startEvent.timestamp
                            editingStartTime = true
                        },
                        onSave: {
                            TripPairingService.shared.updateEventTime(startEvent, newTime: tempStartTime)
                            editingStartTime = false
                        },
                        onCancel: {
                            editingStartTime = false
                        }
                    )
                }
                
                if let endEvent = trip.endEvent {
                    EventRowView(
                        title: "Arrival",
                        location: endLocation.first?.name ?? "Unknown",
                        time: endEvent.timestamp,
                        source: endEvent.eventSource?.displayName ?? "Unknown",
                        wasEdited: endEvent.wasEdited,
                        isEditing: editingEndTime,
                        tempTime: $tempEndTime,
                        onEditTap: {
                            tempEndTime = endEvent.timestamp
                            editingEndTime = true
                        },
                        onSave: {
                            TripPairingService.shared.updateEventTime(endEvent, newTime: tempEndTime)
                            editingEndTime = false
                        },
                        onCancel: {
                            editingEndTime = false
                        }
                    )
                }
            }
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Duration")
                .font(.headline)
            
            if let duration = trip.durationSeconds {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    
                    Text(duration.formattedDuration)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .rounded(radius: 8)
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .font(.headline)
            
            TextField("Add notes about this trip...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color.gray.opacity(0.05))
                .rounded(radius: 8)
        }
    }
    
    private var deleteSection: some View {
        VStack {
            Button(action: { showingDeleteAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Trip")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .rounded(radius: 12)
            }
        }
    }
    
    private func loadTripData() {
        notes = trip.notes ?? ""
    }
    
    private func saveChanges() {
        TripPairingService.shared.updateTripNotes(trip, notes: notes.isEmpty ? nil : notes)
    }
    
    private func deleteTrip() {
        TripPairingService.shared.deleteTrip(trip)
        dismiss()
    }
}

struct EventRowView: View {
    let title: String
    let location: String
    let time: Date
    let source: String
    let wasEdited: Bool
    let isEditing: Bool
    @Binding var tempTime: Date
    let onEditTap: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if wasEdited {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isEditing {
                    HStack {
                        Button("Cancel", action: onCancel)
                            .font(.caption)
                        Button("Save", action: onSave)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                } else {
                    Button(action: onEditTap) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if isEditing {
                DatePicker("Time", selection: $tempTime, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(CompactDatePickerStyle())
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(time.dateTimeString())
                        .font(.body)
                    
                    Text("Source: \(source)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .rounded(radius: 8)
    }
}

struct TripDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        // Create a sample trip
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.notes = "Sample trip notes"
        
        let startEvent = Event(context: context)
        startEvent.id = UUID()
        startEvent.eventKind = .left
        startEvent.timestamp = Date().addingTimeInterval(-3600)
        startEvent.locationId = UUID()
        
        let endEvent = Event(context: context)
        endEvent.id = UUID()
        endEvent.eventKind = .arrived
        endEvent.timestamp = Date()
        endEvent.locationId = UUID()
        
        trip.startEvent = startEvent
        trip.endEvent = endEvent
        
        return TripDetailView(trip: trip)
            .environment(\.managedObjectContext, context)
    }
}