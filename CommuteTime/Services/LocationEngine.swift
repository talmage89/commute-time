import Foundation
import CoreLocation
import CoreData
import os.log

class LocationEngine: NSObject, ObservableObject {
    static let shared = LocationEngine()
    
    private let locationManager = CLLocationManager()
    private let logger = Logger(subsystem: "CommuteTime", category: "LocationEngine")
    private var lastEventTimestamps: [UUID: Date] = [:]
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isMonitoring = false
    
    private var persistenceController: PersistenceController {
        PersistenceController.shared
    }
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Minimum distance for updates
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func start() {
        logger.info("Starting LocationEngine")
        requestLocationPermissions()
        startSignificantLocationChangeMonitoring()
        registerExistingGeofences()
        startVisitMonitoring()
    }
    
    func stop() {
        logger.info("Stopping LocationEngine")
        stopAllMonitoring()
        isMonitoring = false
    }
    
    // MARK: - Permission Management
    
    func requestLocationPermissions() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            logger.warning("Location access denied or restricted")
        case .authorizedAlways:
            logger.info("Already have always authorization")
        @unknown default:
            logger.warning("Unknown authorization status")
        }
    }
    
    // MARK: - Geofence Management
    
    func registerGeofence(for location: Location) {
        guard authorizationStatus == .authorizedAlways else {
            logger.warning("Cannot register geofence without always authorization")
            return
        }
        
        let region = location.coreLocationRegion
        locationManager.startMonitoring(for: region)
        logger.info("Registered geofence for location: \(location.name ?? "Unknown")")
    }
    
    func unregisterGeofence(for location: Location) {
        let regionIdentifier = location.id!.uuidString
        let regionsToRemove = locationManager.monitoredRegions.filter { $0.identifier == regionIdentifier }
        
        for region in regionsToRemove {
            locationManager.stopMonitoring(for: region)
            logger.info("Unregistered geofence for location: \(location.name ?? "Unknown")")
        }
    }
    
    private func registerExistingGeofences() {
        guard authorizationStatus == .authorizedAlways else { return }
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        
        do {
            let locations = try context.fetch(request)
            for location in locations {
                registerGeofence(for: location)
            }
            logger.info("Registered \(locations.count) existing geofences")
        } catch {
            logger.error("Failed to fetch locations for geofence registration: \(error)")
        }
    }
    
    // MARK: - Monitoring Management
    
    private func startSignificantLocationChangeMonitoring() {
        guard authorizationStatus == .authorizedAlways else { return }
        locationManager.startMonitoringSignificantLocationChanges()
        logger.info("Started significant location change monitoring")
    }
    
    private func startVisitMonitoring() {
        guard authorizationStatus == .authorizedAlways else { return }
        locationManager.startMonitoringVisits()
        logger.info("Started visit monitoring")
        isMonitoring = true
    }
    
    private func stopAllMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()
        
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }
    
    // MARK: - Event Creation
    
    private func createEvent(kind: EventKind, source: EventSource, location: Location) {
        // Check for debounce
        let locationId = location.id!
        let now = Date()
        
        if let lastEventTime = lastEventTimestamps[locationId] {
            let timeSinceLastEvent = now.timeIntervalSince(lastEventTime)
            if timeSinceLastEvent < TimeInterval(Constants.debounceWindowMinutes * 60) {
                logger.info("Debounced event for location \(location.name ?? "Unknown") - too recent")
                return
            }
        }
        
        let context = persistenceController.container.viewContext
        let event = Event(context: context)
        event.id = UUID()
        event.eventKind = kind
        event.eventSource = source
        event.timestamp = now
        event.locationId = locationId
        event.wasEdited = false
        event.createdAt = now
        event.updatedAt = now
        event.location = location
        
        do {
            try context.save()
            lastEventTimestamps[locationId] = now
            
            logger.info("Created \(kind.rawValue) event for \(location.name ?? "Unknown") from \(source.rawValue)")
            
            // Notify trip pairing service
            TripPairingService.shared.processEvent(event)
            
            // Send local notification
            NotificationService.shared.sendEventNotification(for: event, location: location)
            
        } catch {
            logger.error("Failed to save event: \(error)")
        }
    }
    
    private func findLocationForCoordinate(_ coordinate: CLLocationCoordinate2D) -> Location? {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        
        do {
            let locations = try context.fetch(request)
            
            for location in locations {
                let locationCoordinate = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let eventLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = locationCoordinate.distance(from: eventLocation)
                
                if distance <= location.radiusMeters {
                    return location
                }
            }
        } catch {
            logger.error("Failed to fetch locations: \(error)")
        }
        
        return nil
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationEngine: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        logger.info("Location authorization changed to: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways:
            start()
        case .authorizedWhenInUse:
            // Request always authorization for background monitoring
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            stop()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion,
              let locationId = UUID(uuidString: region.identifier) else {
            logger.warning("Invalid region entered: \(region.identifier)")
            return
        }
        
        logger.info("Entered region: \(region.identifier)")
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", locationId as CVarArg)
        
        do {
            if let location = try context.fetch(request).first {
                createEvent(kind: .arrived, source: .geofenceEnter, location: location)
            }
        } catch {
            logger.error("Failed to fetch location for entered region: \(error)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion,
              let locationId = UUID(uuidString: region.identifier) else {
            logger.warning("Invalid region exited: \(region.identifier)")
            return
        }
        
        logger.info("Exited region: \(region.identifier)")
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", locationId as CVarArg)
        
        do {
            if let location = try context.fetch(request).first {
                createEvent(kind: .left, source: .geofenceExit, location: location)
            }
        } catch {
            logger.error("Failed to fetch location for exited region: \(error)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        logger.info("Visit detected at \(visit.coordinate.latitude), \(visit.coordinate.longitude)")
        
        guard let location = findLocationForCoordinate(visit.coordinate) else {
            logger.info("No matching location found for visit")
            return
        }
        
        // Check if we already have recent geofence events for this location
        let tenMinutesAgo = Date().addingTimeInterval(-10 * 60)
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "locationId == %@ AND timestamp > %@", 
                                      location.id! as CVarArg, tenMinutesAgo as NSDate)
        
        do {
            let recentEvents = try context.fetch(request)
            
            // Create arrival event if no recent geofence entry
            if visit.arrivalDate != Date.distantPast {
                let hasRecentArrival = recentEvents.contains { event in
                    event.eventKind == .arrived && 
                    (event.eventSource == .geofenceEnter || event.eventSource == .visitArrival)
                }
                
                if !hasRecentArrival {
                    let arrivalEvent = Event(context: context)
                    arrivalEvent.id = UUID()
                    arrivalEvent.eventKind = .arrived
                    arrivalEvent.eventSource = .visitArrival
                    arrivalEvent.timestamp = visit.arrivalDate
                    arrivalEvent.locationId = location.id!
                    arrivalEvent.wasEdited = false
                    arrivalEvent.createdAt = Date()
                    arrivalEvent.updatedAt = Date()
                    arrivalEvent.location = location
                    
                    try context.save()
                    TripPairingService.shared.processEvent(arrivalEvent)
                    NotificationService.shared.sendEventNotification(for: arrivalEvent, location: location)
                    
                    logger.info("Created visit arrival event for \(location.name ?? "Unknown")")
                }
            }
            
            // Create departure event if no recent geofence exit
            if visit.departureDate != Date.distantFuture {
                let hasRecentDeparture = recentEvents.contains { event in
                    event.eventKind == .left && 
                    (event.eventSource == .geofenceExit || event.eventSource == .visitDeparture)
                }
                
                if !hasRecentDeparture {
                    let departureEvent = Event(context: context)
                    departureEvent.id = UUID()
                    departureEvent.eventKind = .left
                    departureEvent.eventSource = .visitDeparture
                    departureEvent.timestamp = visit.departureDate
                    departureEvent.locationId = location.id!
                    departureEvent.wasEdited = false
                    departureEvent.createdAt = Date()
                    departureEvent.updatedAt = Date()
                    departureEvent.location = location
                    
                    try context.save()
                    TripPairingService.shared.processEvent(departureEvent)
                    NotificationService.shared.sendEventNotification(for: departureEvent, location: location)
                    
                    logger.info("Created visit departure event for \(location.name ?? "Unknown")")
                }
            }
            
        } catch {
            logger.error("Failed to process visit: \(error)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Used for significant location changes - refresh geofences if needed
        logger.info("Significant location change detected")
        
        // Re-register geofences to ensure they're active
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.registerExistingGeofences()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location manager failed with error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        logger.error("Monitoring failed for region \(region?.identifier ?? "unknown"): \(error)")
    }
}