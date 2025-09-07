import Foundation
import CoreLocation
import CoreData

// MARK: - Event Types
enum EventKind: String, CaseIterable {
    case left = "left"
    case arrived = "arrived"
    
    var displayName: String {
        switch self {
        case .left:
            return "Left"
        case .arrived:
            return "Arrived"
        }
    }
}

enum EventSource: String, CaseIterable {
    case geofenceEnter = "geofence_enter"
    case geofenceExit = "geofence_exit"
    case visitArrival = "visit_arrival"
    case visitDeparture = "visit_departure"
    case manualEdit = "manual_edit"
    
    var displayName: String {
        switch self {
        case .geofenceEnter:
            return "Geofence Entry"
        case .geofenceExit:
            return "Geofence Exit"
        case .visitArrival:
            return "Visit Arrival"
        case .visitDeparture:
            return "Visit Departure"
        case .manualEdit:
            return "Manual Edit"
        }
    }
}

// MARK: - Constants
enum Constants {
    static let defaultGeofenceRadius: Double = 175.0
    static let minGeofenceRadius: Double = 100.0
    static let maxGeofenceRadius: Double = 300.0
    static let debounceWindowMinutes: Int = 10
    static let pendingTripExpiryHours: Int = 12
    static let defaultInactivityReminderDays: Int = 2
    static let maxGeofenceCount: Int = 20
}

// MARK: - Trip State
enum TripState {
    case complete(startEvent: Event, endEvent: Event)
    case pendingStart(endEvent: Event)
    case pendingEnd(startEvent: Event)
    
    var isComplete: Bool {
        if case .complete = self {
            return true
        }
        return false
    }
    
    var isPending: Bool {
        !isComplete
    }
}

// MARK: - Location Validation
struct LocationValidator {
    static func isValidRadius(_ radius: Double) -> Bool {
        radius >= Constants.minGeofenceRadius && radius <= Constants.maxGeofenceRadius
    }
    
    static func isValidName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        CLLocationCoordinate2DIsValid(coordinate)
    }
}

// MARK: - Formatting Helpers
extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

extension Date {
    func timeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    func dateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    func relativeDateString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

// MARK: - Core Data Extensions

extension Event {
    var eventKind: EventKind? {
        get { EventKind(rawValue: kind ?? "") }
        set { kind = newValue?.rawValue }
    }
    
    var eventSource: EventSource? {
        get { EventSource(rawValue: source ?? "") }
        set { source = newValue?.rawValue }
    }
}

// MARK: - SwiftUI Extensions

import SwiftUI

extension View {
    func cornerRadius(_ radius: CGFloat) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius))
    }
}
