import Foundation
import CoreLocation
import UIKit
import CoreData

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private let coreDataStack = CoreDataStack.shared
    
    @Published var isTracking = false
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocationUpdate: Date?
    
    // Energy-efficient settings
    private let significantLocationChangeThreshold: CLLocationDistance = 100 // meters
    private let minimumTimeInterval: TimeInterval = 300 // 5 minutes
    private var lastSavedLocation: CLLocation?
    private var lastSaveTime: Date?
    
    // Velocity-based logging settings
    private var lastLocationForVelocity: CLLocation?
    private var currentVelocity: CLLocationSpeed = 0 // m/s
    private var dynamicLoggingInterval: TimeInterval = 300 // Start with 5 minutes
    
    // Speed thresholds for different logging frequencies (converted from km/h to m/s)
    private let drivingThreshold: CLLocationSpeed = 2.5 // m/s (9 km/h) - driving speed
    private let highSpeedThreshold: CLLocationSpeed = 0.83 // m/s (3 km/h) - high speed movement
    private let mediumSpeedThreshold: CLLocationSpeed = 0.5 // m/s (1.8 km/h) - medium speed movement
    private let lowSpeedThreshold: CLLocationSpeed = 0.083 // m/s (0.3 km/h) - low speed movement
    
    // Logging intervals based on speed
    private let drivingInterval: TimeInterval = 5 // 5 seconds for driving
    private let highSpeedInterval: TimeInterval = 10 // 10 seconds for high speed
    private let mediumSpeedInterval: TimeInterval = 30 // 30 seconds for medium speed
    private let lowSpeedInterval: TimeInterval = 60 // 1 minute for low speed
    private let stationaryInterval: TimeInterval = 600 // 10 minutes when stationary
    
    override init() {
        super.init()
        setupLocationManager()
        checkLowPowerMode()
        setupLowPowerModeObserver()
        
        // Auto-start tracking if we already have permission
        if authorizationStatus == .authorizedAlways {
            startTracking()
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Energy-efficient accuracy
        locationManager.distanceFilter = significantLocationChangeThreshold
        
        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false // Keep tracking in background
        
        // Request appropriate authorization
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        print("🔍 Current authorization status: \(authorizationStatus.rawValue)")
        
        // Check if location services are enabled on the device
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services are disabled on this device")
            showLocationServicesDisabledAlert()
            return
        }
        
        switch authorizationStatus {
        case .notDetermined:
            print("📱 Requesting 'When In Use' location permission first...")
            // CRITICAL: Must request When In Use first to enable Always option
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("❌ Location permission denied or restricted - user must enable in Settings")
            showLocationPermissionAlert()
        case .authorizedWhenInUse:
            print("✅ Have 'When In Use' - requesting 'Always' permission for background tracking...")
            // Now we can request Always permission
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            print("🎯 Location permission already granted for always access")
            startTracking()
        @unknown default:
            print("❓ Unknown authorization status")
            break
        }
    }
    
    func requestAlwaysPermission() {
        print("Manually requesting 'Always' location permission...")
        switch authorizationStatus {
        case .notDetermined:
            print("No permission yet - requesting 'When In Use' first...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            print("Have 'When In Use' - requesting 'Always' permission...")
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            print("Already have 'Always' permission")
        case .denied, .restricted:
            print("Permission denied - cannot request Always permission")
            showLocationPermissionAlert()
        @unknown default:
            break
        }
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedAlways else {
            print("❌ Cannot start tracking: Need 'Always' permission (current: \(authorizationStatus.rawValue))")
            requestLocationPermission()
            return
        }
        
        // Check background app refresh
        checkBackgroundAppRefresh()
        
        // Ensure background location updates are enabled
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false // Keep tracking in background
        
        // Use significant location changes for energy efficiency
        locationManager.startMonitoringSignificantLocationChanges()
        isTracking = true
        
        // Also start standard location updates with energy-efficient settings
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = significantLocationChangeThreshold
        locationManager.startUpdatingLocation()
        
        print("✅ Location tracking started with velocity-based dynamic logging")
        print("📱 Background location updates: \(locationManager.allowsBackgroundLocationUpdates)")
        print("⏸️ Pauses automatically: \(locationManager.pausesLocationUpdatesAutomatically)")
        print("🎯 Accuracy: \(locationManager.desiredAccuracy)")
        print("📏 Distance filter: \(locationManager.distanceFilter)")
        print("⏰ Dynamic logging intervals:")
        print("   🚗 Driving (≥9 km/h): Every \(Int(drivingInterval))s")
        print("   🏃 High speed (3-9 km/h): Every \(Int(highSpeedInterval))s")
        print("   🚶 Medium speed (1.8-3 km/h): Every \(Int(mediumSpeedInterval))s")
        print("   🐌 Low speed (0.3-1.8 km/h): Every \(Int(lowSpeedInterval))s")
        print("   🛑 Stationary (<0.3 km/h): Every \(Int(stationaryInterval))s")
        print("📐 Distance threshold: \(significantLocationChangeThreshold) meters")
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        isTracking = false
        print("Location tracking stopped")
    }
    
    private func shouldSaveLocation(_ location: CLLocation) -> Bool {
        // Don't save if accuracy is too poor
        guard location.horizontalAccuracy <= 100 else { return false } // 100m accuracy threshold
        
        // Calculate velocity and update logging interval
        updateVelocityAndLoggingInterval(location)
        
        // Check time interval (using dynamic interval based on velocity)
        if let lastTime = lastSaveTime {
            guard Date().timeIntervalSince(lastTime) >= dynamicLoggingInterval else { 
                print("⏰ Not enough time passed: \(Int(Date().timeIntervalSince(lastTime)))s < \(Int(dynamicLoggingInterval))s (velocity: \(String(format: "%.1f", currentVelocity)) m/s)")
                return false 
            }
        }
        
        // Check distance from last saved location
        if let lastLocation = lastSavedLocation {
            let distance = location.distance(from: lastLocation)
            guard distance >= significantLocationChangeThreshold else { return false }
        }
        
        return true
    }
    
    private func updateVelocityAndLoggingInterval(_ location: CLLocation) {
        // Calculate velocity if we have a previous location
        if let lastLocation = lastLocationForVelocity {
            let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            let distance = location.distance(from: lastLocation)
            
            if timeInterval > 0 {
                currentVelocity = distance / timeInterval
                
                // Update logging interval based on velocity
                let previousInterval = dynamicLoggingInterval
                
                if currentVelocity >= drivingThreshold {
                    dynamicLoggingInterval = drivingInterval
                    print("🚗 Driving detected: \(String(format: "%.1f", currentVelocity)) m/s (\(String(format: "%.1f", currentVelocity * 3.6)) km/h) - logging every \(Int(drivingInterval))s")
                } else if currentVelocity >= highSpeedThreshold {
                    dynamicLoggingInterval = highSpeedInterval
                    print("🏃 High speed detected: \(String(format: "%.1f", currentVelocity)) m/s (\(String(format: "%.1f", currentVelocity * 3.6)) km/h) - logging every \(Int(highSpeedInterval))s")
                } else if currentVelocity >= mediumSpeedThreshold {
                    dynamicLoggingInterval = mediumSpeedInterval
                    print("🚶 Medium speed detected: \(String(format: "%.1f", currentVelocity)) m/s (\(String(format: "%.1f", currentVelocity * 3.6)) km/h) - logging every \(Int(mediumSpeedInterval))s")
                } else if currentVelocity >= lowSpeedThreshold {
                    dynamicLoggingInterval = lowSpeedInterval
                    print("🐌 Low speed detected: \(String(format: "%.1f", currentVelocity)) m/s (\(String(format: "%.1f", currentVelocity * 3.6)) km/h) - logging every \(Int(lowSpeedInterval))s")
                } else {
                    dynamicLoggingInterval = stationaryInterval
                    print("🛑 Stationary detected: \(String(format: "%.1f", currentVelocity)) m/s (\(String(format: "%.1f", currentVelocity * 3.6)) km/h) - logging every \(Int(stationaryInterval))s")
                }
                
                // Log when interval changes
                if previousInterval != dynamicLoggingInterval {
                    print("🔄 Logging interval changed from \(Int(previousInterval))s to \(Int(dynamicLoggingInterval))s")
                }
            }
        }
        
        // Update the location for next velocity calculation
        lastLocationForVelocity = location
    }
    
    private func saveLocation(_ location: CLLocation) {
        coreDataStack.saveLocation(location)
        lastSavedLocation = location
        lastSaveTime = Date()
        lastLocationUpdate = Date()
        
        print("Location saved: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Clean up old locations periodically
        if Int.random(in: 1...10) == 1 { // 10% chance
            coreDataStack.deleteOldLocations(olderThan: 30)
        }
    }
    
    private func showLocationPermissionAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Location Permission Required",
                message: "Please enable location access in Settings to track your location history.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(alert, animated: true)
            }
        }
    }
    
    private func showLocationServicesDisabledAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Location Services Disabled",
                message: "Location services are disabled on this device. Please enable them in Settings > Privacy & Security > Location Services.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(alert, animated: true)
            }
        }
    }
    
    func getLocationHistory(limit: Int = 1000) -> [Location] {
        return coreDataStack.fetchLocations(limit: limit)
    }
    
    func deleteAllLocationHistory() {
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        do {
            let locations = try coreDataStack.context.fetch(request)
            for location in locations {
                coreDataStack.context.delete(location)
            }
            coreDataStack.saveContext()
            print("All location history deleted")
        } catch {
            print("Error deleting location history: \(error)")
        }
    }
    
    private func checkBackgroundAppRefresh() {
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        switch backgroundRefreshStatus {
        case .available:
            print("✅ Background App Refresh is available")
        case .denied:
            print("❌ Background App Refresh is denied - this will prevent background location tracking")
            print("📱 Please enable Background App Refresh in Settings > General > Background App Refresh")
        case .restricted:
            print("⚠️ Background App Refresh is restricted - background location tracking may be limited")
        @unknown default:
            print("❓ Background App Refresh status unknown")
        }
    }
    
    private func checkLowPowerMode() {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            print("⚠️ LOW POWER MODE ENABLED - Location tracking may be limited")
            print("📱 Background location updates may be paused by iOS")
            print("🔋 Consider disabling Low Power Mode for full location tracking")
        } else {
            print("✅ Normal power mode - Full location tracking available")
        }
    }
    
    func getLowPowerModeStatus() -> Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    func getCurrentVelocity() -> CLLocationSpeed {
        return currentVelocity
    }
    
    func getCurrentLoggingInterval() -> TimeInterval {
        return dynamicLoggingInterval
    }
    
    func getVelocityBasedLoggingInfo() -> String {
        let speedKmh = currentVelocity * 3.6
        let intervalMinutes = dynamicLoggingInterval / 60
        
        var speedCategory = "Unknown"
        if currentVelocity >= drivingThreshold {
            speedCategory = "Driving (≥9 km/h)"
        } else if currentVelocity >= highSpeedThreshold {
            speedCategory = "High Speed (3-9 km/h)"
        } else if currentVelocity >= mediumSpeedThreshold {
            speedCategory = "Medium Speed (1.8-3 km/h)"
        } else if currentVelocity >= lowSpeedThreshold {
            speedCategory = "Low Speed (0.3-1.8 km/h)"
        } else {
            speedCategory = "Stationary (<0.3 km/h)"
        }
        
        return """
        Velocity-Based Logging Status:
        🚗 Current Speed: \(String(format: "%.1f", currentVelocity)) m/s (\(String(format: "%.1f", speedKmh)) km/h)
        📊 Speed Category: \(speedCategory)
        ⏰ Logging Interval: \(Int(dynamicLoggingInterval))s (\(String(format: "%.1f", intervalMinutes)) min)
        📍 Last Update: \(lastLocationUpdate?.formatted() ?? "Never")
        """
    }
    
    func getBackgroundTrackingStatus() -> String {
        var status = "Background Tracking Status:\n"
        
        // Check location permission
        switch authorizationStatus {
        case .authorizedAlways:
            status += "✅ Location: Always allowed\n"
        case .authorizedWhenInUse:
            status += "❌ Location: When In Use only (need Always)\n"
        case .denied, .restricted:
            status += "❌ Location: Denied/Restricted\n"
        case .notDetermined:
            status += "⏳ Location: Not determined\n"
        @unknown default:
            status += "❓ Location: Unknown status\n"
        }
        
        // Check background app refresh
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        switch backgroundRefreshStatus {
        case .available:
            status += "✅ Background App Refresh: Available\n"
        case .denied:
            status += "❌ Background App Refresh: Denied\n"
        case .restricted:
            status += "⚠️ Background App Refresh: Restricted\n"
        @unknown default:
            status += "❓ Background App Refresh: Unknown\n"
        }
        
        // Check low power mode
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            status += "⚠️ Low Power Mode: Enabled (may limit tracking)\n"
        } else {
            status += "✅ Low Power Mode: Disabled\n"
        }
        
        // Check tracking status
        if isTracking {
            status += "✅ Location Tracking: Active\n"
        } else {
            status += "❌ Location Tracking: Inactive\n"
        }
        
        return status
    }
    
    private func setupLowPowerModeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lowPowerModeChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }
    
    @objc private func lowPowerModeChanged() {
        DispatchQueue.main.async {
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                print("🔋 LOW POWER MODE ENABLED - Location tracking may be limited")
                print("📱 iOS may pause background location updates")
            } else {
                print("✅ LOW POWER MODE DISABLED - Full location tracking restored")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let appState = UIApplication.shared.applicationState
        let stateString = appState == .active ? "FOREGROUND" : (appState == .background ? "BACKGROUND" : "INACTIVE")
        
        print("📍 Location update received in \(stateString): \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("🎯 Accuracy: \(location.horizontalAccuracy)m, Time: \(location.timestamp)")
        
        currentLocation = location
        
        // Only save location if it meets our energy-efficient criteria
        if shouldSaveLocation(location) {
            saveLocation(location)
        } else {
            print("⏭️ Location not saved (doesn't meet criteria)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔄 Authorization status changed to: \(status.rawValue)")
        authorizationStatus = status
        
        switch status {
        case .authorizedAlways:
            print("✅ Location permission granted for 'Always' access - background tracking enabled")
            startTracking()
        case .authorizedWhenInUse:
            print("⚠️ Location permission granted for 'When In Use' - now requesting 'Always' permission for background tracking...")
            // Automatically request Always permission after When In Use is granted
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🔄 Requesting 'Always' permission after 'When In Use' was granted...")
                self.locationManager.requestAlwaysAuthorization()
            }
        case .denied, .restricted:
            print("❌ Location permission denied or restricted - user must enable in Settings")
            stopTracking()
            showLocationPermissionAlert()
        case .notDetermined:
            print("⏳ Location permission not determined yet - will request on next attempt")
            break
        @unknown default:
            print("❓ Unknown authorization status: \(status.rawValue)")
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error)")
        
        // Handle specific errors
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("🚫 Location access denied - stopping tracking")
                stopTracking()
                showLocationPermissionAlert()
            case .locationUnknown:
                print("📍 Location unknown - this is temporary, continuing tracking")
                // Temporary error, continue tracking
                break
            case .network:
                print("🌐 Network error - check internet connection")
                break
            case .headingFailure:
                print("🧭 Heading failure - not critical for location tracking")
                break
            default:
                print("❓ Location error: \(clError.localizedDescription) (Code: \(clError.code.rawValue))")
            }
        } else {
            print("❓ Unknown error type: \(error)")
        }
    }
}
