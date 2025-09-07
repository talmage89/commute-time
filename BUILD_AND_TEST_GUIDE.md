# CommuteTime App - Build & Test Guide

## 🛠️ Building the App

### Prerequisites
- **Xcode 15.0+** (for iOS 16+ support)
- **macOS Ventura 13.0+**
- **iOS device** (iPhone/iPad) for location testing
- **Apple Developer Account** (free tier acceptable for 7-day provisioning)

### Step 1: Open and Configure Project

1. **Open Xcode Project:**
   ```bash
   cd /Users/talmage/coding/commute-time
   open CommuteTime.xcodeproj
   ```

2. **Configure Signing & Capabilities:**
   - Select `CommuteTime` target in project navigator
   - Go to "Signing & Capabilities" tab
   - Set your **Team** (Apple ID or Developer Account)
   - Ensure **Bundle Identifier** is unique (e.g., `com.yourname.CommuteTime`)
   - Verify these capabilities are enabled:
     - ✅ **Background Modes** → Location updates
     - ✅ **Push Notifications** (for local notifications)

3. **Verify Info.plist Permissions:**
   - Check that these usage descriptions are present:
     - `NSLocationWhenInUseUsageDescription`
     - `NSLocationAlwaysAndWhenInUseUsageDescription`
     - `NSUserNotificationsUsageDescription`

### Step 2: Build Process

1. **Select Target Device:**
   - Choose your physical iOS device (not simulator - location services need real device)
   - Ensure device is connected and trusted

2. **Build & Run:**
   - Press `Cmd + R` or click the ▶️ button
   - First build may take 2-3 minutes (compiling Core Data model, etc.)
   - App should install and launch on your device

### Step 3: Verify Installation

✅ **Success Indicators:**
- App icon appears on device home screen
- App launches without crashes
- Permissions screen appears on first launch
- No build errors in Xcode console

❌ **Common Issues & Fixes:**
- **Signing Error**: Update Bundle ID and ensure valid Apple ID
- **Location Permission Error**: Check Info.plist descriptions
- **Core Data Error**: Clean build folder (`Cmd + Shift + K`)

---

## 🧪 Testing the App Properly

### Phase 1: Basic App Functionality (5 minutes)

#### 1.1 First Launch Flow
- [ ] App shows permissions screen on first launch
- [ ] "Enable Location (Always)" button works
- [ ] "Enable Notifications" button works
- [ ] App transitions to main trips list after permissions

#### 1.2 UI Navigation
- [ ] Empty trips list shows appropriate message
- [ ] "Locations" button opens modal
- [ ] Modal can be dismissed
- [ ] Navigation feels smooth and responsive

### Phase 2: Location Management (10 minutes)

#### 2.1 Add Your First Location
1. **Tap "Locations" button** → Opens locations modal
2. **Tap "+" or "Add Location"**
3. **Enter a name** (e.g., "Home", "Office")
4. **Adjust radius** slider (try 150-200m for testing)
5. **Tap "Use Current Location"** → Should capture GPS coordinates
6. **Save the location**

✅ **Expected Results:**
- Location appears in list
- Geofence counter shows "1 of 20 used"
- Modal closes automatically

#### 2.2 Test Location Editing
- [ ] Edit location name
- [ ] Adjust radius (100-300m range)
- [ ] Changes save properly
- [ ] Delete location works (if needed)

### Phase 3: Location Tracking (30-60 minutes)

> **⚠️ Important:** This requires moving between physical locations with your device!

#### 3.1 Setup Test Locations

**Recommended Test Setup:**
1. **Add "Home"** location where you currently are
2. **Add "Test Location"** at a nearby place (office, store, friend's house, etc.)
3. **Ensure locations are 200+ meters apart** for reliable geofence triggers

#### 3.2 Test Departure Detection

1. **Start at Location A** (should be "inside" the geofence)
2. **Wait 2-3 minutes** for geofence to register
3. **Walk/drive away from Location A** (beyond the radius)
4. **Check for notification** within 5-10 minutes:
   - Should receive: "Left [Location A] at [time]"
5. **Open app** → Should see pending trip: "Leaving [Location A]..."

#### 3.3 Test Arrival Detection

1. **Travel to Location B** (your second test location)
2. **Enter the geofence area** (within the radius)
3. **Wait for notification**: "Arrived at [Location B] at [time]"
4. **Open app** → Should see completed trip:
   - "To [Location B]"
   - Duration displayed
   - Both start and end times shown

#### 3.4 Background Testing

1. **Close the app** (swipe up, swipe away)
2. **Repeat location changes** with app in background
3. **Verify notifications still arrive**
4. **Open app later** → All trips should be recorded

### Phase 4: Trip Management (15 minutes)

#### 4.1 Trip Detail Editing
1. **Tap on a completed trip** → Opens detail view
2. **Edit departure time** using time picker
3. **Edit arrival time** using time picker
4. **Add notes** (e.g., "Test trip via Main St.")
5. **Save changes**

✅ **Verify:**
- Duration updates automatically
- Times reflect your edits
- Notes are saved
- `wasEdited` flag is set (visible in CSV export)

#### 4.2 Trip Deletion
1. **Open trip detail**
2. **Tap "Delete Trip"** (red button)
3. **Confirm deletion**
4. **Verify trip disappears** from list

### Phase 5: Data Export (5 minutes)

#### 5.1 CSV Export Test
1. **Create 2-3 test trips** (using above steps)
2. **Tap export button** in trips list
3. **Share to Files app**
4. **Open CSV file** and verify columns:
   - `trip_id, start_time, start_location, start_source, end_time, end_location, end_source, duration_seconds, notes, start_was_edited, end_was_edited`

### Phase 6: Edge Case Testing (20 minutes)

#### 6.1 Same-Location Filtering
1. **Test leaving and immediately returning** to same location
2. **Verify no trip is created** for same-location events
3. **Check that events are properly debounced** (10-minute window)

#### 6.2 Pending Trip Expiration
1. **Create a "left" event** (leave a location)
2. **Don't complete the trip** for 30+ minutes
3. **Force-quit and reopen app**
4. **Verify pending trip handling** (should show as incomplete after 12 hours)

#### 6.3 Permission Revocation
1. **Go to Settings** → Privacy & Security → Location Services
2. **Find CommuteTime** → Change to "Never"
3. **Test app behavior** (should handle gracefully)
4. **Re-enable permissions** → Should resume tracking

### Phase 7: Performance & Battery Testing (Ongoing)

#### 7.1 Battery Impact
- **Monitor battery usage** in Settings → Battery
- **CommuteTime should rank low** in battery usage
- **Compare to other location apps** (Maps, Weather, etc.)

#### 7.2 Memory Usage
- **Open Xcode** → Debug Navigator
- **Monitor memory usage** while app runs
- **Should remain under 50MB** for normal usage

---

## 🐛 Debugging Common Issues

### Location Not Triggering
1. **Check permissions**: Settings → Privacy → Location Services
2. **Verify radius**: Try increasing to 200-300m
3. **Test movement distance**: Ensure you're moving 200+ meters
4. **Check iOS version**: Location services behave differently on different versions

### Notifications Not Appearing
1. **Check notification permissions**: Settings → Notifications → CommuteTime
2. **Verify Focus/Do Not Disturb** is not blocking
3. **Test with app closed** (notifications only appear when app is backgrounded)

### Trips Not Pairing
1. **Check logs in Xcode console** for pairing service messages
2. **Verify locations are different** (same-location filter active)
3. **Ensure sufficient time gap** between events (debounce window)

### Core Data Errors
1. **Clean build** (`Cmd + Shift + K`)
2. **Delete app from device** and reinstall
3. **Check Xcode console** for specific Core Data error messages

---

## 📊 Success Metrics

### ✅ App is Working Correctly When:

1. **Battery usage < 5%** over 24 hours of normal use
2. **95%+ accuracy** for location enter/exit detection
3. **Notifications arrive within 5-10 minutes** of location change
4. **Background tracking works** when app is closed
5. **Data persists** through app restarts and device reboots
6. **CSV export contains complete data** for all trips
7. **UI remains responsive** with 100+ trips in database

### 📈 Recommended Test Timeline

- **Day 1**: Setup, basic functionality, first location tests
- **Day 2-3**: Daily commute testing, background behavior
- **Week 1**: Edge cases, multiple locations, data export
- **Ongoing**: Long-term battery monitoring, accuracy assessment

---

## 🚀 Production Readiness Checklist

Before using as your primary commute tracker:

- [ ] **2+ weeks of testing** without major issues
- [ ] **All core locations added** and tested
- [ ] **Battery impact acceptable** for daily use
- [ ] **Notification timing satisfactory** for your needs
- [ ] **Data export works** for your record-keeping
- [ ] **Backup strategy** (periodic CSV exports)

---

**Need Help?** Check the Xcode console for detailed logs, or review the app's service implementations in `/CommuteTime/Services/` for debugging specific issues.
