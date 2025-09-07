import Foundation
import CoreData

class CSVExporter: ObservableObject {
    
    func generateCSV(from trips: [Trip]) -> URL? {
        let csvContent = generateCSVContent(from: trips)
        return saveCSVToFile(content: csvContent)
    }
    
    private func generateCSVContent(from trips: [Trip]) -> String {
        var csvLines: [String] = []
        
        // Add header
        let header = "trip_id,start_time,start_location,start_source,end_time,end_location,end_source,duration_seconds,notes,start_was_edited,end_was_edited"
        csvLines.append(header)
        
        let context = PersistenceController.shared.container.viewContext
        
        // Process each trip
        for trip in trips {
            let row = generateCSVRow(for: trip, context: context)
            csvLines.append(row)
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    private func generateCSVRow(for trip: Trip, context: NSManagedObjectContext) -> String {
        let tripId = trip.id?.uuidString ?? ""
        
        // Start event data
        let startTime = trip.startEvent?.timestamp?.iso8601String() ?? ""
        let startLocationName = getLocationName(for: trip.startEvent?.locationId, context: context)
        let startSource = trip.startEvent?.source ?? ""
        let startWasEdited = trip.startEvent?.wasEdited ?? false
        
        // End event data
        let endTime = trip.endEvent?.timestamp?.iso8601String() ?? ""
        let endLocationName = getLocationName(for: trip.endEvent?.locationId, context: context)
        let endSource = trip.endEvent?.source ?? ""
        let endWasEdited = trip.endEvent?.wasEdited ?? false
        
        // Trip data
        let durationSeconds = trip.durationSeconds?.formatted() ?? ""
        let notes = escapeCsvField(trip.notes ?? "")
        
        // Build CSV row
        let fields = [
            escapeCsvField(tripId),
            escapeCsvField(startTime),
            escapeCsvField(startLocationName),
            escapeCsvField(startSource),
            escapeCsvField(endTime),
            escapeCsvField(endLocationName),
            escapeCsvField(endSource),
            escapeCsvField(durationSeconds),
            notes,
            startWasEdited ? "true" : "false",
            endWasEdited ? "true" : "false"
        ]
        
        return fields.joined(separator: ",")
    }
    
    private func getLocationName(for locationId: UUID?, context: NSManagedObjectContext) -> String {
        guard let locationId = locationId else { return "" }
        
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", locationId as CVarArg)
        request.fetchLimit = 1
        
        do {
            let location = try context.fetch(request).first
            return location?.name ?? "Unknown Location"
        } catch {
            return "Unknown Location"
        }
    }
    
    private func escapeCsvField(_ field: String) -> String {
        // Escape quotes and wrap in quotes if necessary
        let needsQuotes = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        
        if needsQuotes {
            let escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        } else {
            return field
        }
    }
    
    private func saveCSVToFile(content: String) -> URL? {
        let fileName = "commute_time_export_\(Date().filenameDateString()).csv"
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write CSV file: \(error)")
            return nil
        }
    }
}

// MARK: - Date Extensions

extension Date {
    func filenameDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: self)
    }
}

extension TimeInterval {
    func formatted() -> String {
        return String(format: "%.0f", self)
    }
}
