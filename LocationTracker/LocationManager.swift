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
    
    // Energy-efficient settings (TESTING: 10 seconds for easy verification)
    private let significantLocationChangeThreshold: CLLocationDistance = 10 // meters (reduced for testing)
    private let minimumTimeInterval: TimeInterval = 10 // 10 seconds (for testing)
    private var lastSavedLocation: CLLocation?
    private var lastSaveTime: Date?
    
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
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // High accuracy for testing
        locationManager.distanceFilter = 1 // 1 meter for testing (very sensitive)
        
        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false // Keep tracking in background
        
        // Request appropriate authorization
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            print("Requesting 'Always' location permission for background tracking...")
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            print("Location permission denied or restricted")
            showLocationPermissionAlert()
        case .authorizedWhenInUse:
            print("Upgrading from 'When In Use' to 'Always' permission for background tracking...")
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            print("Location permission already granted for always access")
            startTracking()
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
        
        // Also start standard location updates with high frequency for testing
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1 // 1 meter for testing
        locationManager.startUpdatingLocation()
        
        print("✅ Location tracking started with TESTING settings and background updates enabled")
        print("📱 Background location updates: \(locationManager.allowsBackgroundLocationUpdates)")
        print("⏸️ Pauses automatically: \(locationManager.pausesLocationUpdatesAutomatically)")
        print("🎯 Accuracy: \(locationManager.desiredAccuracy)")
        print("📏 Distance filter: \(locationManager.distanceFilter)")
        print("⏰ Logging frequency: Every \(minimumTimeInterval) seconds")
        print("📐 Distance threshold: \(significantLocationChangeThreshold) meters")
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        isTracking = false
        print("Location tracking stopped")
    }
    
    private func shouldSaveLocation(_ location: CLLocation) -> Bool {
        // Don't save if accuracy is too poor (relaxed for testing)
        guard location.horizontalAccuracy <= 500 else { return false } // 500m for testing
        
        // Check time interval
        if let lastTime = lastSaveTime {
            guard Date().timeIntervalSince(lastTime) >= minimumTimeInterval else { return false }
        }
        
        // Check distance from last saved location
        if let lastLocation = lastSavedLocation {
            let distance = location.distance(from: lastLocation)
            guard distance >= significantLocationChangeThreshold else { return false }
        }
        
        return true
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
        authorizationStatus = status
        
        switch status {
        case .authorizedAlways:
            print("✅ Location permission granted for 'Always' access - background tracking enabled")
            startTracking()
        case .authorizedWhenInUse:
            print("⚠️ Location permission granted for 'When In Use' only - background tracking not available")
            print("🔄 Requesting 'Always' access for background tracking...")
            // Request always authorization for background tracking
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.locationManager.requestAlwaysAuthorization()
            }
        case .denied, .restricted:
            print("❌ Location permission denied or restricted")
            stopTracking()
            showLocationPermissionAlert()
        case .notDetermined:
            print("⏳ Location permission not determined yet")
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
        
        // Handle specific errors
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                stopTracking()
                showLocationPermissionAlert()
            case .locationUnknown:
                // Temporary error, continue tracking
                break
            default:
                print("Location error: \(clError.localizedDescription)")
            }
        }
    }
}
