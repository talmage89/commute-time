import XCTest
import CoreData
import CoreLocation
@testable import CommuteTime

final class CommuteTimeTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var persistenceController: PersistenceController!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        testContext = persistenceController.container.viewContext
    }
    
    override func tearDownWithError() throws {
        testContext = nil
        persistenceController = nil
    }
    
    // MARK: - Location Tests
    
    func testLocationCreation() throws {
        let location = Location(context: testContext)
        location.id = UUID()
        location.name = "Test Location"
        location.latitude = 37.7749
        location.longitude = -122.4194
        location.radiusMeters = 175
        location.isActive = true
        
        try testContext.save()
        
        XCTAssertNotNil(location.id)
        XCTAssertEqual(location.name, "Test Location")
        XCTAssertEqual(location.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(location.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(location.radiusMeters, 175)
        XCTAssertTrue(location.isActive)
    }
    
    func testLocationCoordinateProperty() throws {
        let location = Location(context: testContext)
        location.latitude = 37.7749
        location.longitude = -122.4194
        
        let coordinate = location.coordinate
        XCTAssertEqual(coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, -122.4194, accuracy: 0.0001)
    }
    
    func testLocationCoreLocationRegion() throws {
        let location = Location(context: testContext)
        location.id = UUID()
        location.latitude = 37.7749
        location.longitude = -122.4194
        location.radiusMeters = 200
        
        let region = location.coreLocationRegion
        
        XCTAssertEqual(region.center.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(region.radius, 200, accuracy: 0.1)
        XCTAssertEqual(region.identifier, location.id!.uuidString)
        XCTAssertTrue(region.notifyOnEntry)
        XCTAssertTrue(region.notifyOnExit)
    }
    
    // MARK: - Event Tests
    
    func testEventCreation() throws {
        let location = createTestLocation(name: "Home")
        let event = Event(context: testContext)
        event.id = UUID()
        event.eventKind = .arrived
        event.eventSource = .geofenceEnter
        event.timestamp = Date()
        event.locationId = location.id!
        event.wasEdited = false
        event.createdAt = Date()
        event.updatedAt = Date()
        event.location = location
        
        try testContext.save()
        
        XCTAssertNotNil(event.id)
        XCTAssertEqual(event.eventKind, .arrived)
        XCTAssertEqual(event.eventSource, .geofenceEnter)
        XCTAssertFalse(event.wasEdited)
        XCTAssertEqual(event.location, location)
    }
    
    func testEventKindEnum() throws {
        let event = Event(context: testContext)
        
        event.eventKind = .left
        XCTAssertEqual(event.kind, "left")
        
        event.eventKind = .arrived
        XCTAssertEqual(event.kind, "arrived")
        
        event.kind = "left"
        XCTAssertEqual(event.eventKind, .left)
        
        event.kind = "arrived"
        XCTAssertEqual(event.eventKind, .arrived)
    }
    
    func testEventSourceEnum() throws {
        let event = Event(context: testContext)
        
        event.eventSource = .geofenceEnter
        XCTAssertEqual(event.source, "geofence_enter")
        
        event.eventSource = .visitArrival
        XCTAssertEqual(event.source, "visit_arrival")
        
        event.source = "geofence_exit"
        XCTAssertEqual(event.eventSource, .geofenceExit)
        
        event.source = "manual_edit"
        XCTAssertEqual(event.eventSource, .manualEdit)
    }
    
    // MARK: - Trip Tests
    
    func testTripCreation() throws {
        let homeLocation = createTestLocation(name: "Home")
        let workLocation = createTestLocation(name: "Work")
        
        let startEvent = createTestEvent(kind: .left, location: homeLocation)
        let endEvent = createTestEvent(kind: .arrived, location: workLocation, timestamp: Date().addingTimeInterval(1800)) // 30 minutes later
        
        let trip = Trip(context: testContext)
        trip.id = UUID()
        trip.startEvent = startEvent
        trip.endEvent = endEvent
        trip.notes = "Test trip"
        
        try testContext.save()
        
        XCTAssertNotNil(trip.id)
        XCTAssertEqual(trip.startEvent, startEvent)
        XCTAssertEqual(trip.endEvent, endEvent)
        XCTAssertEqual(trip.notes, "Test trip")
        XCTAssertTrue(trip.isComplete)
        XCTAssertFalse(trip.isPending)
    }
    
    func testTripDurationCalculation() throws {
        let location = createTestLocation(name: "Test")
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(1800) // 30 minutes
        
        let startEvent = createTestEvent(kind: .left, location: location, timestamp: startTime)
        let endEvent = createTestEvent(kind: .arrived, location: location, timestamp: endTime)
        
        let trip = Trip(context: testContext)
        trip.startEvent = startEvent
        trip.endEvent = endEvent
        
        XCTAssertEqual(trip.startTime, startTime)
        XCTAssertEqual(trip.endTime, endTime)
        XCTAssertEqual(trip.durationSeconds, 1800, accuracy: 0.1)
    }
    
    func testPendingTrip() throws {
        let location = createTestLocation(name: "Test")
        let startEvent = createTestEvent(kind: .left, location: location)
        
        let trip = Trip(context: testContext)
        trip.startEvent = startEvent
        trip.endEvent = nil
        
        XCTAssertFalse(trip.isComplete)
        XCTAssertTrue(trip.isPending)
        XCTAssertNil(trip.durationSeconds)
    }
    
    // MARK: - Trip Pairing Service Tests
    
    func testTripPairingServiceLeftEvent() throws {
        let tripPairingService = TripPairingService.shared
        let location = createTestLocation(name: "Home")
        let leftEvent = createTestEvent(kind: .left, location: location)
        
        // Simulate processing a left event
        tripPairingService.processEvent(leftEvent)
        
        // Verify a trip was created
        let trips = tripPairingService.getAllTrips()
        XCTAssertEqual(trips.count, 1)
        
        let trip = trips.first!
        XCTAssertEqual(trip.startEvent, leftEvent)
        XCTAssertNil(trip.endEvent)
        XCTAssertTrue(trip.isPending)
    }
    
    func testTripPairingServiceCompleteTrip() throws {
        let tripPairingService = TripPairingService.shared
        let homeLocation = createTestLocation(name: "Home")
        let workLocation = createTestLocation(name: "Work")
        
        let leftEvent = createTestEvent(kind: .left, location: homeLocation)
        let arrivedEvent = createTestEvent(kind: .arrived, location: workLocation, timestamp: Date().addingTimeInterval(1800))
        
        // Process events in order
        tripPairingService.processEvent(leftEvent)
        tripPairingService.processEvent(arrivedEvent)
        
        // Verify trip was completed
        let trips = tripPairingService.getAllTrips()
        XCTAssertEqual(trips.count, 1)
        
        let trip = trips.first!
        XCTAssertEqual(trip.startEvent, leftEvent)
        XCTAssertEqual(trip.endEvent, arrivedEvent)
        XCTAssertTrue(trip.isComplete)
        XCTAssertFalse(trip.isPending)
    }
    
    func testTripPairingServiceSameLocationNoTrip() throws {
        let tripPairingService = TripPairingService.shared
        let location = createTestLocation(name: "Home")
        
        let leftEvent = createTestEvent(kind: .left, location: location)
        let arrivedEvent = createTestEvent(kind: .arrived, location: location, timestamp: Date().addingTimeInterval(300))
        
        // Process events
        tripPairingService.processEvent(leftEvent)
        tripPairingService.processEvent(arrivedEvent)
        
        // Should still be pending (arrived at same location as departure)
        let trips = tripPairingService.getAllTrips()
        XCTAssertEqual(trips.count, 1)
        
        let trip = trips.first!
        XCTAssertEqual(trip.startEvent, leftEvent)
        XCTAssertNil(trip.endEvent) // Should not set end event for same location
    }
    
    // MARK: - CSV Export Tests
    
    func testCSVExportEmptyTrips() throws {
        let csvExporter = CSVExporter()
        let csvContent = csvExporter.generateCSVContent(from: [])
        
        let expectedHeader = "trip_id,start_time,start_location,start_source,end_time,end_location,end_source,duration_seconds,notes,start_was_edited,end_was_edited"
        XCTAssertEqual(csvContent, expectedHeader)
    }
    
    func testCSVExportCompleteTrip() throws {
        let csvExporter = CSVExporter()
        
        let homeLocation = createTestLocation(name: "Home")
        let workLocation = createTestLocation(name: "Work Office")
        
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(1800)
        
        let startEvent = createTestEvent(kind: .left, location: homeLocation, timestamp: startTime)
        startEvent.eventSource = .geofenceExit
        
        let endEvent = createTestEvent(kind: .arrived, location: workLocation, timestamp: endTime)
        endEvent.eventSource = .geofenceEnter
        
        let trip = Trip(context: testContext)
        trip.id = UUID()
        trip.startEvent = startEvent
        trip.endEvent = endEvent
        trip.notes = "Daily commute"
        
        try testContext.save()
        
        let csvContent = csvExporter.generateCSVContent(from: [trip])
        let lines = csvContent.components(separatedBy: "\n")
        
        XCTAssertEqual(lines.count, 2) // Header + 1 trip
        
        let dataLine = lines[1]
        let fields = dataLine.components(separatedBy: ",")
        
        XCTAssertEqual(fields.count, 11)
        XCTAssertEqual(fields[0], trip.id!.uuidString) // trip_id
        XCTAssertEqual(fields[2], "Home") // start_location
        XCTAssertEqual(fields[3], "geofence_exit") // start_source
        XCTAssertEqual(fields[5], "Work Office") // end_location
        XCTAssertEqual(fields[6], "geofence_enter") // end_source
        XCTAssertEqual(fields[7], "1800") // duration_seconds
        XCTAssertEqual(fields[8], "\"Daily commute\"") // notes (quoted because of space)
        XCTAssertEqual(fields[9], "false") // start_was_edited
        XCTAssertEqual(fields[10], "false") // end_was_edited
    }
    
    // MARK: - Validation Tests
    
    func testLocationValidator() throws {
        XCTAssertTrue(LocationValidator.isValidRadius(150))
        XCTAssertTrue(LocationValidator.isValidRadius(100))
        XCTAssertTrue(LocationValidator.isValidRadius(300))
        XCTAssertFalse(LocationValidator.isValidRadius(50))
        XCTAssertFalse(LocationValidator.isValidRadius(500))
        
        XCTAssertTrue(LocationValidator.isValidName("Home"))
        XCTAssertTrue(LocationValidator.isValidName("  Work  "))
        XCTAssertFalse(LocationValidator.isValidName(""))
        XCTAssertFalse(LocationValidator.isValidName("   "))
        
        let validCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let invalidCoordinate = CLLocationCoordinate2D(latitude: 200, longitude: -300)
        
        XCTAssertTrue(LocationValidator.isValidCoordinate(validCoordinate))
        XCTAssertFalse(LocationValidator.isValidCoordinate(invalidCoordinate))
    }
    
    // MARK: - Duration Formatting Tests
    
    func testTimeIntervalFormatting() throws {
        XCTAssertEqual(TimeInterval(65).formattedDuration, "1:05")
        XCTAssertEqual(TimeInterval(3661).formattedDuration, "1:01:01")
        XCTAssertEqual(TimeInterval(45).formattedDuration, "0:45")
        XCTAssertEqual(TimeInterval(7200).formattedDuration, "2:00:00")
    }
    
    // MARK: - Helper Methods
    
    private func createTestLocation(name: String) -> Location {
        let location = Location(context: testContext)
        location.id = UUID()
        location.name = name
        location.latitude = 37.7749
        location.longitude = -122.4194
        location.radiusMeters = 175
        location.isActive = true
        return location
    }
    
    private func createTestEvent(kind: EventKind, location: Location, timestamp: Date = Date()) -> Event {
        let event = Event(context: testContext)
        event.id = UUID()
        event.eventKind = kind
        event.eventSource = .geofenceEnter
        event.timestamp = timestamp
        event.locationId = location.id!
        event.wasEdited = false
        event.createdAt = timestamp
        event.updatedAt = timestamp
        event.location = location
        return event
    }
}

// MARK: - Performance Tests

extension CommuteTimeTests {
    
    func testTripQueryPerformance() throws {
        // Create a large number of trips for performance testing
        for i in 0..<1000 {
            let location = createTestLocation(name: "Location \(i)")
            let startEvent = createTestEvent(kind: .left, location: location)
            let endEvent = createTestEvent(kind: .arrived, location: location, timestamp: Date().addingTimeInterval(Double(i * 60)))
            
            let trip = Trip(context: testContext)
            trip.id = UUID()
            trip.startEvent = startEvent
            trip.endEvent = endEvent
        }
        
        try testContext.save()
        
        // Measure performance of fetching all trips
        measure {
            let tripPairingService = TripPairingService.shared
            _ = tripPairingService.getAllTrips()
        }
    }
    
    func testCSVExportPerformance() throws {
        var trips: [Trip] = []
        
        // Create trips for performance testing
        for i in 0..<100 {
            let location = createTestLocation(name: "Location \(i)")
            let startEvent = createTestEvent(kind: .left, location: location)
            let endEvent = createTestEvent(kind: .arrived, location: location, timestamp: Date().addingTimeInterval(Double(i * 60)))
            
            let trip = Trip(context: testContext)
            trip.id = UUID()
            trip.startEvent = startEvent
            trip.endEvent = endEvent
            trip.notes = "Trip \(i) notes with some longer text to test CSV escaping"
            
            trips.append(trip)
        }
        
        try testContext.save()
        
        let csvExporter = CSVExporter()
        
        // Measure CSV generation performance
        measure {
            _ = csvExporter.generateCSVContent(from: trips)
        }
    }
}
