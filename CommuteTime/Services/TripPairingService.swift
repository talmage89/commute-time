import Foundation
import CoreData
import os.log

class TripPairingService: ObservableObject {
    static let shared = TripPairingService()
    
    private let logger = Logger(subsystem: "CommuteTime", category: "TripPairingService")
    private var currentPendingTrip: Trip?
    
    private var persistenceController: PersistenceController {
        PersistenceController.shared
    }
    
    private init() {}
    
    func start() {
        logger.info("Starting TripPairingService")
        loadPendingTrip()
        cleanupExpiredTrips()
    }
    
    // MARK: - Event Processing
    
    func processEvent(_ event: Event) {
        logger.info("Processing event: \(event.eventKind?.rawValue ?? "unknown") for location \(event.locationId?.uuidString ?? "unknown")")
        
        guard let eventKind = event.eventKind else {
            logger.error("Event has invalid kind")
            return
        }
        
        switch eventKind {
        case .left:
            handleLeftEvent(event)
        case .arrived:
            handleArrivedEvent(event)
        }
        
        updateAppSettings(lastEventAt: event.timestamp ?? Date())
    }
    
    // MARK: - Trip Pairing Logic
    
    private func handleLeftEvent(_ event: Event) {
        let context = persistenceController.container.viewContext
        
        // Create or update the single pending trip with startEvent
        if let pendingTrip = currentPendingTrip {
            // Update existing pending trip
            pendingTrip.startEvent = event
            logger.info("Updated existing pending trip with start event")
        } else {
            // Create new pending trip
            let trip = Trip(context: context)
            trip.id = UUID()
            trip.startEvent = event
            trip.endEvent = nil
            trip.notes = nil
            currentPendingTrip = trip
            logger.info("Created new pending trip with start event")
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to save trip: \(error)")
        }
    }
    
    private func handleArrivedEvent(_ event: Event) {
        let context = persistenceController.container.viewContext
        
        // Check if this arrival is at the same location as the pending start
        if let pendingTrip = currentPendingTrip,
           let startEvent = pendingTrip.startEvent,
           startEvent.locationId == event.locationId {
            logger.info("Arrived at same location as departure - not creating trip")
            return
        }
        
        if let pendingTrip = currentPendingTrip, pendingTrip.startEvent != nil {
            // Complete the pending trip
            pendingTrip.endEvent = event
            currentPendingTrip = nil
            logger.info("Completed trip with arrival event")
        } else {
            // Create a pending trip with only arrival event
            let trip = Trip(context: context)
            trip.id = UUID()
            trip.startEvent = nil
            trip.endEvent = event
            trip.notes = nil
            currentPendingTrip = trip
            logger.info("Created pending trip with arrival event only")
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to save trip: \(error)")
        }
    }
    
    // MARK: - Pending Trip Management
    
    private func loadPendingTrip() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "startEvent == nil OR endEvent == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startEvent?.timestamp, ascending: false)]
        request.fetchLimit = 1
        
        do {
            currentPendingTrip = try context.fetch(request).first
            if let pendingTrip = currentPendingTrip {
                logger.info("Loaded existing pending trip")
                
                // Check if pending trip has expired
                if isPendingTripExpired(pendingTrip: pendingTrip) {
                    logger.info("Pending trip has expired")
                    // Keep the trip but clear it from current pending
                    currentPendingTrip = nil
                }
            }
        } catch {
            logger.error("Failed to load pending trip: \(error)")
        }
    }
    
    private func isPendingTripExpired(pendingTrip: Trip) -> Bool {
        guard let startEvent = pendingTrip.startEvent else { return false }
        
        let expiryTime = (startEvent.timestamp ?? Date()).addingTimeInterval(TimeInterval(Constants.pendingTripExpiryHours * 3600))
        return Date() > expiryTime
    }
    
    private func cleanupExpiredTrips() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "endEvent == nil AND startEvent != nil")
        
        do {
            let pendingTrips = try context.fetch(request)
            var expiredCount = 0
            
            for trip in pendingTrips {
                if isPendingTripExpired(pendingTrip: trip) {
                    // Mark as expired but don't delete - let it remain as incomplete
                    expiredCount += 1
                }
            }
            
            if expiredCount > 0 {
                logger.info("Found \(expiredCount) expired pending trips")
            }
        } catch {
            logger.error("Failed to cleanup expired trips: \(error)")
        }
    }
    
    // MARK: - Manual Trip Management
    
    func createManualTrip(startTime: Date, endTime: Date, startLocationId: UUID, endLocationId: UUID, notes: String?) -> Trip? {
        let context = persistenceController.container.viewContext
        
        // Create manual events
        let startEvent = Event(context: context)
        startEvent.id = UUID()
        startEvent.eventKind = .left
        startEvent.eventSource = .manualEdit
        startEvent.timestamp = startTime
        startEvent.locationId = startLocationId
        startEvent.wasEdited = true
        startEvent.createdAt = Date()
        startEvent.updatedAt = Date()
        
        let endEvent = Event(context: context)
        endEvent.id = UUID()
        endEvent.eventKind = .arrived
        endEvent.eventSource = .manualEdit
        endEvent.timestamp = endTime
        endEvent.locationId = endLocationId
        endEvent.wasEdited = true
        endEvent.createdAt = Date()
        endEvent.updatedAt = Date()
        
        // Create trip
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.startEvent = startEvent
        trip.endEvent = endEvent
        trip.notes = notes
        
        do {
            try context.save()
            logger.info("Created manual trip")
            return trip
        } catch {
            logger.error("Failed to create manual trip: \(error)")
            return nil
        }
    }
    
    func deleteTrip(_ trip: Trip) {
        let context = persistenceController.container.viewContext
        
        // Clear current pending trip if it's this one
        if currentPendingTrip?.id == trip.id {
            currentPendingTrip = nil
        }
        
        context.delete(trip)
        
        do {
            try context.save()
            logger.info("Deleted trip")
        } catch {
            logger.error("Failed to delete trip: \(error)")
        }
    }
    
    func updateTripNotes(_ trip: Trip, notes: String?) {
        trip.notes = notes
        
        do {
            try persistenceController.container.viewContext.save()
            logger.info("Updated trip notes")
        } catch {
            logger.error("Failed to update trip notes: \(error)")
        }
    }
    
    func updateEventTime(_ event: Event, newTime: Date) {
        event.timestamp = newTime
        event.wasEdited = true
        event.updatedAt = Date()
        
        do {
            try persistenceController.container.viewContext.save()
            logger.info("Updated event time")
        } catch {
            logger.error("Failed to update event time: \(error)")
        }
    }
    
    // MARK: - App Settings
    
    private func updateAppSettings(lastEventAt: Date) {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        
        do {
            let settings = try context.fetch(request).first ?? AppSettings(context: context)
            settings.lastEventAt = lastEventAt
            try context.save()
        } catch {
            logger.error("Failed to update app settings: \(error)")
        }
    }
    
    // MARK: - Query Methods
    
    func getAllTrips() -> [Trip] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Trip.endEvent?.timestamp, ascending: false),
            NSSortDescriptor(keyPath: \Trip.startEvent?.timestamp, ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            logger.error("Failed to fetch trips: \(error)")
            return []
        }
    }
    
    func getCompletedTrips() -> [Trip] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "startEvent != nil AND endEvent != nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.endEvent?.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            logger.error("Failed to fetch completed trips: \(error)")
            return []
        }
    }
    
    func getPendingTrips() -> [Trip] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "startEvent == nil OR endEvent == nil")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Trip.endEvent?.timestamp, ascending: false),
            NSSortDescriptor(keyPath: \Trip.startEvent?.timestamp, ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            logger.error("Failed to fetch pending trips: \(error)")
            return []
        }
    }
}
