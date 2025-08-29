## Commute Time – App Specification (MVP)

### Overview

Minimal iOS app that automatically records arrival and departure events for user-defined places using low-power location services, pairs events into trips, and displays a simple reverse-chronological list with a basic detail screen for edits and deletion. Storage is on-device only; manual CSV export is available.

### Goals

- **Minimal UI**: one list screen + a simple detail screen; a lightweight locations manager modal.
- **Low battery impact**: rely on geofencing, visits, and significant-change updates (no continuous GPS).
- **Accurate enough**: choose conservative geofence radii to reduce false triggers.
- **Simple data**: events and trips with timestamps; optional trip notes; on-device storage.

### Non-Goals (MVP)

- No cloud sync, accounts, or dashboards.
- No Shortcuts/URL schemes.
- No dark mode or theme settings.
- No filters or analytics.
- No commute time windows; tracking is always on (subject to permissions).

### Platform & Distribution

- iOS, personal device.
- Free Xcode provisioning (7‑day re-sign) acceptable for now.

### Permissions & Background Modes

- Request Location: When In Use → upgrade to Always.
- Background Modes: `location`.
- Local Notifications: for event logging confirmations and inactivity reminder.

### Location Strategy (Battery-Friendly)

- Primary: Geofences per user location (enter → Arrived, exit → Left).
- Backup: Visits (`startMonitoringVisits`) to backfill missed enter/exit.
- Reliability: Significant-change updates (`startMonitoringSignificantLocationChanges`) to keep geofences refreshed.
- Debounce: ignore duplicate enter/exit for the same location within 10 minutes.
- System limit: respect ~20 monitored regions per app (active locations capped accordingly).

### Data Model

- **Location**
  - `id: UUID`
  - `name: String`
  - `latitude: Double`
  - `longitude: Double`
  - `radiusMeters: Double` (default 175; allowed 100–300)
  - `isActive: Bool` (default true)

- **Event**
  - `id: UUID`
  - `kind: enum { left, arrived }`
  - `timestamp: Date`
  - `locationId: UUID` (FK → Location)
  - `source: enum { geofence_enter, geofence_exit, visit_arrival, visit_departure, manual_edit }`
  - `wasEdited: Bool` (default false)
  - `createdAt: Date`
  - `updatedAt: Date`

- **Trip**
  - `id: UUID`
  - `startEventId: UUID?` (FK → Event.kind = left)
  - `endEventId: UUID?` (FK → Event.kind = arrived)
  - `notes: String?`
  - Derived (not stored): `startTime`, `endTime`, `durationSeconds`
  - Deletion rule: deleting a Trip cascades deletion of its associated Events.

- **AppSettings**
  - `lastEventAt: Date?`
  - `daysWithoutEventForReminder: Int` (default 2)
  - `hasRequestedAlwaysPermission: Bool`

### Event Generation Rules

- Geofence enter for a Location → `Event(kind=arrived, source=geofence_enter)`.
- Geofence exit for a Location → `Event(kind=left, source=geofence_exit)`.
- Visit fallback: `visit_arrival`/`visit_departure` used only if geofence counterpart is absent within ±10 minutes; prefer geofence when both exist in that window.
- Debounce repeated enter/exit for the same Location within 10 minutes.

### Trip Pairing Rules

- On `left(A)`: create or update the single pending Trip with `startEvent=A`.
- On next `arrived(B)` where `B ≠ A`: set `endEvent=B` and finalize the Trip (compute duration).
- If `arrived(B)` occurs without a pending start: create a pending Trip with only `endEvent=B` (shown as pending until a future matching `left` happens; otherwise remains partial).
- Incomplete `left` older than 12 hours: mark pending/expired (still listed, no duration).

### UI Flow

- **First Launch (Permissions)**
  - Brief screen explaining background location use.
  - Buttons: “Enable Location (Always)” and “Enable Notifications”. Proceed to list after granting or skipping.

- **Trips List (Root)**
  - Reverse-chronological list of Trips.
  - Row states:
    - Complete: Title “To [Arrival Location]”; subtitle “Duration [mm:ss] • [date/time]”.
    - Pending (left only): Title “Leaving [Location]…”; subtitle “Started [time]”.
    - Pending (arrival only): Title “To [Arrival Location] (pending start)”; subtitle “[time]”.
  - Top-right button: “Locations” (modal).

- **Trip Detail**
  - Shows Departure and Arrival times with time-only editors (DatePicker).
  - Editing adjusts `Event.timestamp` and sets `wasEdited=true`; duration recomputed.
  - Notes: simple multiline field on Trip.
  - Delete Trip (destructive) → cascades events.

- **Locations Modal**
  - List of user-defined locations with add/edit/delete; display remaining geofence slots (out of ~20).
  - Add Location (required flow):
    - Fields: `Name` (text), `Geofence Radius` (slider 100–300 m, default 175).
    - Source of coordinates: must use current GPS position (“Use Current Location” required; no manual coordinate entry, no map pin-drop in MVP).
    - Save → creates Location and registers geofence.
  - Edit: update name/radius; moving coordinates requires deleting and re-adding (keeps MVP simple).

### Notifications

- Local notification for each recorded event:
  - “Arrived at [Location] at [time]” or “Left [Location] at [time]”.
- Inactivity reminder:
  - If no events for ≥ 48 hours (configurable via `daysWithoutEventForReminder`), send “No location activity detected.”
  - Otherwise fail silently when permissions are off.

### Export

- Manual export via share sheet to Files as CSV.
- CSV columns:
  - `trip_id, start_time, start_location, start_source, end_time, end_location, end_source, duration_seconds, notes, start_was_edited, end_was_edited`

### Error Handling & Edge Cases

- Permissions revoked: app remains silent; inactivity reminder still applies.
- Urban canyon/indoors drift: mitigate with larger default radius (175 m) and debounce window.
- Device reboot: geofences re-registered on app wake via significant-change listener and persistence.

### Technical Components

- **LocationEngine**: wraps `CLLocationManager`; manages geofences, visits, significant-change; deduplicates and emits normalized Events.
- **TripPairingService**: maintains pending Trip and pairs Events into Trips; handles expirations.
- **Persistence**: Core Data (or SQLite wrapper) with cascade rules; fetch controllers for list UI.
- **NotificationCenter**: schedules local notifications for events and inactivity.

### Acceptance Criteria (MVP)

- User can create locations only from current GPS position and set radius (100–300 m).
- App records Arrived/Left events in the background and pairs them into Trips.
- List screen shows reverse-chronological Trips with clear states (complete/pending).
- Detail screen allows editing event times and adding notes; deleting a Trip cascades events.
- Local notifications fire on event creation; a single reminder after 48 hours of inactivity.
- Manual CSV export works and includes specified columns.
- Battery usage remains low (no continuous GPS).

### Defaults

- Geofence radius default: 175 m.
- Debounce window: 10 minutes.
- Pending start expiry: 12 hours.
- Inactivity reminder threshold: 2 days.


