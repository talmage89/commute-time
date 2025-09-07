# CommuteTime - iOS App

A minimal iOS app that automatically records arrival and departure events for user-defined places using low-power location services, pairs events into trips, and displays a simple reverse-chronological list with editing capabilities.

## Features

### Core Functionality
- **Automatic Location Tracking**: Uses geofencing, visits, and significant-change location updates for battery-efficient monitoring
- **Smart Trip Pairing**: Automatically pairs departure and arrival events into meaningful trips
- **Background Operation**: Continues tracking when app is in background (requires "Always" location permission)
- **Local Storage**: All data stored locally using Core Data - no cloud sync required

### User Interface
- **Permissions Screen**: Clean onboarding flow for location and notification permissions
- **Trips List**: Reverse-chronological list of all trips with status indicators
- **Trip Details**: Edit trip times, add notes, view duration and locations
- **Location Management**: Add, edit, and manage geofenced locations (up to 20 active)
- **CSV Export**: Manual export of trip data via share sheet

### Technical Features
- **Low Battery Impact**: Relies on geofencing and visits, not continuous GPS
- **Debouncing**: Ignores duplicate events within 10-minute windows
- **Smart Fallbacks**: Uses visit detection when geofence events are missed
- **Local Notifications**: Event confirmations and inactivity reminders
- **Comprehensive Testing**: Unit tests for core business logic

## Architecture

### Core Components

#### LocationEngine
- Wraps `CLLocationManager`
- Manages geofences, visits, and significant location changes
- Handles event deduplication and normalization
- Provides battery-efficient location monitoring

#### TripPairingService
- Maintains pending trips and pairs events
- Handles complex trip logic (same-location filtering, expiration)
- Manages manual trip creation and editing
- Provides query methods for UI

#### PersistenceController
- Core Data stack management
- Handles data model relationships and cascade rules
- Provides preview data for SwiftUI previews

#### NotificationService
- Local notification management
- Event notifications and inactivity reminders
- Badge count management
- Permission handling

### Data Model

#### Location
- User-defined places with geofencing
- Configurable radius (100-300m, default 175m)
- Active/inactive state management
- Automatic geofence registration

#### Event
- Individual arrival/departure events
- Multiple sources (geofence, visit, manual)
- Edit tracking and timestamps
- Linked to locations

#### Trip
- Pairs of events representing journeys
- Optional notes and duration calculation
- Supports partial trips (pending start/end)
- Cascade deletion of events

#### AppSettings
- Last event timestamp for inactivity detection
- Notification preferences
- Permission state tracking

## Usage

### First Launch
1. Grant location permissions (When In Use → Always)
2. Optionally enable notifications
3. Add your first location using current GPS position

### Adding Locations
1. Navigate to Locations from the main menu
2. Tap "+" to add a new location
3. Enter a name and adjust the geofence radius
4. Save - geofence will be automatically registered

### Automatic Tracking
- App automatically detects when you enter/exit geofenced areas
- Events are paired into trips based on departure → arrival sequences
- Trips appear in the main list in reverse chronological order

### Manual Editing
- Tap any trip to view details
- Edit departure/arrival times using date pickers
- Add notes to trips
- Delete trips if needed

### Data Export
- Use the main menu to export trip data as CSV
- Includes all trip details, durations, and metadata
- Share via standard iOS share sheet

## Technical Requirements

- iOS 16.0+
- Location permissions (Always for background tracking)
- Notification permissions (optional, for event alerts)

## Privacy & Permissions

- **Location**: Required for core functionality. Uses "Always" permission for background geofencing
- **Notifications**: Optional for event confirmations and inactivity reminders
- **Data**: All data stored locally on device, no cloud sync or external transmission

## Build Instructions

1. Open `CommuteTime.xcodeproj` in Xcode 15+
2. Select your development team for code signing
3. Build and run on device (location services require physical device)
4. Grant location permissions when prompted

## Testing

Run tests using Xcode's test navigator or command line:
```bash
xcodebuild test -scheme CommuteTime -destination 'platform=iOS Simulator,name=iPhone 15'
```

Tests cover:
- Core Data model validation
- Trip pairing logic
- CSV export functionality  
- Location validation
- Duration calculations
- Performance benchmarks

## Architecture Decisions

### Battery Optimization
- Primary reliance on geofencing (iOS handles efficiently)
- Visits as backup for missed geofence events
- Significant location changes for geofence refresh
- No continuous GPS tracking

### Data Integrity
- 10-minute debounce window prevents duplicate events
- Same-location arrivals don't complete trips
- Expired pending trips (12+ hours) remain as incomplete
- Manual edit tracking with timestamps

### User Experience
- Conservative 175m default radius reduces false triggers
- Clear visual indicators for trip states
- Minimal UI with essential features only
- Immediate feedback via notifications

## Future Enhancements (Not in MVP)

- Cloud sync and backup
- Dark mode support
- Analytics and insights
- Shortcuts integration
- Advanced filtering and search
- Time-based automation rules

## License

This project is provided as an example implementation. Modify as needed for your use case.
