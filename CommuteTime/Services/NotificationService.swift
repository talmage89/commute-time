import Foundation
import UserNotifications
import CoreData
import os.log

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private let logger = Logger(subsystem: "CommuteTime", category: "NotificationService")
    private let notificationCenter = UNUserNotificationCenter.current()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private var persistenceController: PersistenceController {
        PersistenceController.shared
    }
    
    private init() {}
    
    func setup() {
        logger.info("Setting up NotificationService")
        requestNotificationPermissions()
        checkAuthorizationStatus()
        scheduleInactivityReminderIfNeeded()
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.logger.error("Notification permission error: \(error)")
                } else {
                    self?.logger.info("Notification permission granted: \(granted)")
                }
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    // MARK: - Event Notifications
    
    func sendEventNotification(for event: Event, location: Location) {
        guard authorizationStatus == .authorized else {
            logger.warning("Cannot send notification - not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        switch event.eventKind {
        case .arrived:
            content.title = "Arrived"
            content.body = "Arrived at \(location.name ?? "Unknown Location") at \(event.timestamp.timeString())"
        case .left:
            content.title = "Departed"
            content.body = "Left \(location.name ?? "Unknown Location") at \(event.timestamp.timeString())"
        case .none:
            return
        }
        
        // Add location name to user info for potential future use
        content.userInfo = [
            "eventId": event.id?.uuidString ?? "",
            "locationId": location.id?.uuidString ?? "",
            "eventKind": event.kind ?? "",
            "locationName": location.name ?? ""
        ]
        
        // Use immediate trigger since this is a real-time notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "event_\(event.id?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to schedule event notification: \(error)")
            } else {
                self?.logger.info("Scheduled event notification for \(event.eventKind?.rawValue ?? "unknown") at \(location.name ?? "unknown")")
            }
        }
    }
    
    // MARK: - Inactivity Reminders
    
    func scheduleInactivityReminderIfNeeded() {
        guard authorizationStatus == .authorized else { return }
        
        // Cancel existing inactivity reminders
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["inactivity_reminder"])
        
        let context = persistenceController.container.viewContext
        let settingsRequest: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        
        do {
            let settings = try context.fetch(settingsRequest).first
            let daysThreshold = settings?.daysWithoutEventForReminder ?? Constants.defaultInactivityReminderDays
            let lastEventDate = settings?.lastEventAt ?? Date.distantPast
            
            let thresholdDate = Date().addingTimeInterval(-TimeInterval(daysThreshold * 24 * 3600))
            
            if lastEventDate < thresholdDate {
                // We're already past the threshold - schedule immediate reminder
                scheduleInactivityReminder(delaySeconds: 1)
            } else {
                // Schedule reminder for when threshold is reached
                let timeUntilThreshold = Date().timeIntervalSince(lastEventDate) + TimeInterval(daysThreshold * 24 * 3600)
                scheduleInactivityReminder(delaySeconds: timeUntilThreshold)
            }
            
        } catch {
            logger.error("Failed to fetch app settings for inactivity reminder: \(error)")
        }
    }
    
    private func scheduleInactivityReminder(delaySeconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "No Activity Detected"
        content.body = "No location activity detected. Make sure location permissions are enabled for background tracking."
        content.sound = .default
        content.userInfo = ["type": "inactivity_reminder"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delaySeconds, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: "inactivity_reminder",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to schedule inactivity reminder: \(error)")
            } else {
                self?.logger.info("Scheduled inactivity reminder for \(delaySeconds) seconds")
            }
        }
    }
    
    func cancelInactivityReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["inactivity_reminder"])
        logger.info("Cancelled inactivity reminder")
    }
    
    // MARK: - Notification Management
    
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        logger.info("Cleared all notifications")
    }
    
    func clearEventNotifications() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let eventNotificationIds = requests
                .filter { $0.identifier.hasPrefix("event_") }
                .map { $0.identifier }
            
            self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: eventNotificationIds)
            self?.logger.info("Cleared \(eventNotificationIds.count) event notifications")
        }
        
        notificationCenter.getDeliveredNotifications { [weak self] notifications in
            let eventNotificationIds = notifications
                .filter { $0.request.identifier.hasPrefix("event_") }
                .map { $0.request.identifier }
            
            self?.notificationCenter.removeDeliveredNotifications(withIdentifiers: eventNotificationIds)
        }
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "startEvent == nil OR endEvent == nil")
        
        do {
            let pendingTripsCount = try context.count(for: request)
            DispatchQueue.main.async {
                UNUserNotificationCenter.current().setBadgeCount(pendingTripsCount) { error in
                    if let error = error {
                        self.logger.error("Failed to update badge count: \(error)")
                    }
                }
            }
        } catch {
            logger.error("Failed to count pending trips for badge: \(error)")
        }
    }
    
    // MARK: - Settings
    
    func updateInactivityReminderThreshold(days: Int) {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        
        do {
            let settings = try context.fetch(request).first ?? AppSettings(context: context)
            settings.daysWithoutEventForReminder = Int32(days)
            try context.save()
            
            // Reschedule with new threshold
            scheduleInactivityReminderIfNeeded()
            
            logger.info("Updated inactivity reminder threshold to \(days) days")
        } catch {
            logger.error("Failed to update inactivity reminder threshold: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String, type == "inactivity_reminder" {
            logger.info("User tapped inactivity reminder")
            // Could potentially open app to locations settings
        } else if let eventId = userInfo["eventId"] as? String {
            logger.info("User tapped event notification: \(eventId)")
            // Could potentially open app to trip details
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}