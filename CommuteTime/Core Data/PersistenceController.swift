import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let homeLocation = Location(context: viewContext)
        homeLocation.id = UUID()
        homeLocation.name = "Home"
        homeLocation.latitude = 37.7749
        homeLocation.longitude = -122.4194
        homeLocation.radiusMeters = 175
        homeLocation.isActive = true
        
        let workLocation = Location(context: viewContext)
        workLocation.id = UUID()
        workLocation.name = "Work"
        workLocation.latitude = 37.7849
        workLocation.longitude = -122.4094
        workLocation.radiusMeters = 200
        workLocation.isActive = true
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DataModel")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func saveContext() {
        save()
    }
}

// MARK: - Core Data Extensions
extension Location {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var coreLocationRegion: CLCircularRegion {
        let region = CLCircularRegion(center: coordinate, radius: radiusMeters, identifier: id!.uuidString)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
}

extension Event {
    enum EventKind: String, CaseIterable {
        case left = "left"
        case arrived = "arrived"
    }
    
    enum EventSource: String, CaseIterable {
        case geofenceEnter = "geofence_enter"
        case geofenceExit = "geofence_exit"
        case visitArrival = "visit_arrival"
        case visitDeparture = "visit_departure"
        case manualEdit = "manual_edit"
    }
    
    var eventKind: EventKind? {
        get { EventKind(rawValue: kind ?? "") }
        set { kind = newValue?.rawValue }
    }
    
    var eventSource: EventSource? {
        get { EventSource(rawValue: source ?? "") }
        set { source = newValue?.rawValue }
    }
}

extension Trip {
    var startTime: Date? {
        startEvent?.timestamp
    }
    
    var endTime: Date? {
        endEvent?.timestamp
    }
    
    var durationSeconds: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }
    
    var isComplete: Bool {
        startEvent != nil && endEvent != nil
    }
    
    var isPending: Bool {
        !isComplete
    }
}

import CoreLocation