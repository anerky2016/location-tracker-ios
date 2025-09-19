import UIKit
import CoreLocation
import MapKit
import Combine

class LocationTrackerViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var historyButton: UIButton!
    @IBOutlet weak var currentLocationLabel: UILabel!
    @IBOutlet weak var lastUpdateLabel: UILabel!
    @IBOutlet weak var batteryOptimizationLabel: UILabel!
    
    private let locationManager = LocationManager.shared
    private var locationHistory: [Location] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMapView()
        observeLocationManager()
        loadLocationHistory()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
        
        // FORCE permission request to enable all iOS Settings options
        print("🔔 View appeared - current auth status: \(locationManager.authorizationStatus.rawValue)")
        
        // Always try to request "When In Use" permission first to enable all options
        if locationManager.authorizationStatus == .notDetermined {
            print("🔔 Requesting 'When In Use' permission to enable all iOS Settings options...")
            locationManager.requestLocationPermission()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse {
            print("🔔 Have 'When In Use' - requesting 'Always' permission...")
            locationManager.requestAlwaysPermission()
        } else {
            print("🔔 Current status: \(locationManager.authorizationStatus.rawValue) - checking if we need to request permissions...")
        }
    }
    
    private func setupUI() {
        title = "📍 Location Tracker"
        
        // Setup modern navigation bar
        setupModernNavigationBar()
        
        // Setup modern buttons with enhanced styling
        setupModernButtons()
        
        // Setup modern labels with better typography
        setupModernLabels()
        
        // Setup modern map view
        setupModernMapView()
        
        // Setup modern status indicators
        updateBatteryStatus()
    }
    
    private func setupModernNavigationBar() {
        // Modern navigation bar styling
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        // Modern settings button with SF Symbol
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        settingsButton.tintColor = .systemBlue
        navigationItem.rightBarButtonItem = settingsButton
    }
    
    private func setupModernButtons() {
        // Modern toggle button with gradient and shadow
        toggleButton.layer.cornerRadius = 16
        toggleButton.layer.shadowColor = UIColor.black.cgColor
        toggleButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        toggleButton.layer.shadowRadius = 8
        toggleButton.layer.shadowOpacity = 0.15
        toggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        // Modern history button with gradient and shadow
        historyButton.layer.cornerRadius = 16
        historyButton.layer.shadowColor = UIColor.black.cgColor
        historyButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        historyButton.layer.shadowRadius = 8
        historyButton.layer.shadowOpacity = 0.15
        historyButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        // Add subtle gradient backgrounds
        addGradientToButton(toggleButton, colors: [UIColor.systemBlue.cgColor, UIColor.systemBlue.withAlphaComponent(0.8).cgColor])
        addGradientToButton(historyButton, colors: [UIColor.systemGreen.cgColor, UIColor.systemGreen.withAlphaComponent(0.8).cgColor])
    }
    
    private func addGradientToButton(_ button: UIButton, colors: [CGColor]) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16
        gradientLayer.frame = button.bounds
        
        // Insert gradient at the bottom of the button's layer stack
        button.layer.insertSublayer(gradientLayer, at: 0)
        
        // Ensure button content is above gradient
        button.bringSubviewToFront(button.titleLabel!)
    }
    
    private func setupModernLabels() {
        // Modern status label with better typography
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        
        // Modern location labels with better spacing
        currentLocationLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        currentLocationLabel.textAlignment = .center
        currentLocationLabel.numberOfLines = 0
        currentLocationLabel.textColor = .secondaryLabel
        
        lastUpdateLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        lastUpdateLabel.textAlignment = .center
        lastUpdateLabel.numberOfLines = 0
        lastUpdateLabel.textColor = .secondaryLabel
        
        batteryOptimizationLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        batteryOptimizationLabel.textAlignment = .center
        batteryOptimizationLabel.numberOfLines = 0
        
        // Set initial text
        statusLabel.text = "Initializing..."
        currentLocationLabel.text = "Current Location: Not available"
        lastUpdateLabel.text = "Last Update: Never"
    }
    
    private func setupModernMapView() {
        // Modern map view styling
        mapView.layer.cornerRadius = 16
        mapView.layer.shadowColor = UIColor.black.cgColor
        mapView.layer.shadowOffset = CGSize(width: 0, height: 4)
        mapView.layer.shadowRadius = 12
        mapView.layer.shadowOpacity = 0.15
        
        // Modern map type
        mapView.mapType = .standard
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsTraffic = false
        mapView.showsBuildings = true
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Add a long press gesture to show location details
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        mapView.addGestureRecognizer(longPressGesture)
    }
    
    private func observeLocationManager() {
        // Observe location manager changes
        locationManager.$isTracking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isTracking in
                self?.updateTrackingStatus(isTracking)
            }
            .store(in: &cancellables)
        
        locationManager.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.updateCurrentLocation(location)
            }
            .store(in: &cancellables)
        
        locationManager.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateAuthorizationStatus(status)
            }
            .store(in: &cancellables)
        
        locationManager.$lastLocationUpdate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                self?.updateLastUpdateTime(date)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func loadLocationHistory() {
        locationHistory = locationManager.getLocationHistory(limit: 100)
        updateMapWithHistory()
    }
    
    private func updateUI() {
        updateTrackingStatus(locationManager.isTracking)
        updateCurrentLocation(locationManager.currentLocation)
        updateAuthorizationStatus(locationManager.authorizationStatus)
        updateLastUpdateTime(locationManager.lastLocationUpdate)
        updateBatteryStatus()
    }
    
    private func updateTrackingStatus(_ isTracking: Bool) {
        if isTracking {
            statusLabel.text = "🟢 Status: Tracking Active"
            statusLabel.textColor = .systemGreen
            toggleButton.setTitle("⏹️ Stop Tracking", for: .normal)
            updateButtonGradient(toggleButton, colors: [UIColor.systemRed.cgColor, UIColor.systemRed.withAlphaComponent(0.8).cgColor])
        } else {
            statusLabel.text = "🔴 Status: Tracking Stopped"
            statusLabel.textColor = .systemRed
            toggleButton.setTitle("▶️ Start Tracking", for: .normal)
            updateButtonGradient(toggleButton, colors: [UIColor.systemBlue.cgColor, UIColor.systemBlue.withAlphaComponent(0.8).cgColor])
        }
    }
    
    private func updateButtonGradient(_ button: UIButton, colors: [CGColor]) {
        // Remove existing gradient layers
        button.layer.sublayers?.removeAll { $0 is CAGradientLayer }
        
        // Add new gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16
        gradientLayer.frame = button.bounds
        
        button.layer.insertSublayer(gradientLayer, at: 0)
        button.bringSubviewToFront(button.titleLabel!)
    }
    
    private func updateCurrentLocation(_ location: CLLocation?) {
        if let location = location {
            currentLocationLabel.text = String(format: "Current Location: %.6f, %.6f", 
                                             location.coordinate.latitude, 
                                             location.coordinate.longitude)
            
            // Update map center
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)
        } else {
            currentLocationLabel.text = "Current Location: Not available"
        }
    }
    
    private func updateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            statusLabel.text = "Status: Authorized (Always)"
            statusLabel.textColor = .systemGreen
        case .authorizedWhenInUse:
            statusLabel.text = "Status: Authorized (When In Use)"
            statusLabel.textColor = .systemOrange
        case .denied:
            statusLabel.text = "Status: Permission Denied"
            statusLabel.textColor = .systemRed
        case .restricted:
            statusLabel.text = "Status: Permission Restricted"
            statusLabel.textColor = .systemRed
        case .notDetermined:
            statusLabel.text = "Status: Permission Not Determined"
            statusLabel.textColor = .systemOrange
        @unknown default:
            statusLabel.text = "Status: Unknown"
            statusLabel.textColor = .systemGray
        }
    }
    
    private func updateLastUpdateTime(_ date: Date?) {
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            lastUpdateLabel.text = "Last Update: \(formatter.string(from: date))"
        } else {
            lastUpdateLabel.text = "Last Update: Never"
        }
    }
    
    private func updateMapWithHistory() {
        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Add location history as annotations
        for (index, location) in locationHistory.prefix(50).enumerated() { // Limit to 50 for performance
            let annotation = LocationAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                title: "Location \(index + 1)",
                subtitle: DateFormatter.localizedString(from: location.timestamp ?? Date(), dateStyle: .short, timeStyle: .short)
            )
            mapView.addAnnotation(annotation)
        }
    }
    
    @IBAction func toggleTracking(_ sender: UIButton) {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Add button press animation
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = CGAffineTransform.identity
            }
        }
        
        if locationManager.isTracking {
            locationManager.stopTracking()
        } else {
            locationManager.startTracking()
        }
    }
    
    @IBAction func showHistory(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let historyVC = storyboard.instantiateViewController(withIdentifier: "LocationHistoryViewController") as? LocationHistoryViewController {
            navigationController?.pushViewController(historyVC, animated: true)
        }
    }
    
    @objc private func showSettings() {
        let alert = UIAlertController(title: "Settings", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Clear All History", style: .destructive) { [weak self] _ in
            self?.showClearHistoryConfirmation()
        })
        
        alert.addAction(UIAlertAction(title: "Refresh Map", style: .default) { [weak self] _ in
            self?.loadLocationHistory()
        })
        
        alert.addAction(UIAlertAction(title: "Location Permissions", style: .default) { [weak self] _ in
            self?.showLocationPermissionInfo()
        })
        
        alert.addAction(UIAlertAction(title: "🔓 Force 'When In Use' Permission", style: .default) { [weak self] _ in
            self?.forceWhenInUsePermission()
        })
        
        alert.addAction(UIAlertAction(title: "Request When In Use Permission", style: .default) { [weak self] _ in
            self?.requestWhenInUsePermission()
        })
        
        alert.addAction(UIAlertAction(title: "Request Always Permission", style: .default) { [weak self] _ in
            self?.requestAlwaysPermission()
        })
        
        alert.addAction(UIAlertAction(title: "Low Power Mode Test", style: .default) { [weak self] _ in
            self?.showLowPowerModeTest()
        })
        
        alert.addAction(UIAlertAction(title: "Background Tracking Status", style: .default) { [weak self] _ in
            self?.showBackgroundTrackingStatus()
        })
        
        alert.addAction(UIAlertAction(title: "Debug Information", style: .default) { [weak self] _ in
            self?.showDebugInfo()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func showClearHistoryConfirmation() {
        let alert = UIAlertController(
            title: "Clear All History",
            message: "This will permanently delete all location history. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { [weak self] _ in
            self?.locationManager.deleteAllLocationHistory()
            self?.loadLocationHistory()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showLocationPermissionInfo() {
        let alert = UIAlertController(
            title: "Location Permissions",
            message: "This app requires 'Always' location permission to track your location in the background. The app uses energy-efficient tracking methods to minimize battery usage.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func requestAlwaysPermission() {
        let alert = UIAlertController(
            title: "Request Always Permission",
            message: "This will request 'Always' location permission for background tracking. You'll see a system dialog asking for permission.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Request Permission", style: .default) { [weak self] _ in
            self?.locationManager.requestAlwaysPermission()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showDebugInfo() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let debugVC = storyboard.instantiateViewController(withIdentifier: "DebugInfoViewController") as? DebugInfoViewController {
            navigationController?.pushViewController(debugVC, animated: true)
        }
    }
    
    private func forceWhenInUsePermission() {
        print("🔓 FORCING 'When In Use' permission request to enable all iOS Settings options...")
        // This should trigger the system dialog and enable all 4 options in iOS Settings
        locationManager.requestLocationPermission()
    }
    
    private func requestWhenInUsePermission() {
        print("🔔 Manually requesting 'When In Use' permission...")
        // Directly request When In Use permission to enable all iOS Settings options
        locationManager.requestLocationPermission()
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            let alert = UIAlertController(
                title: "Location Details",
                message: String(format: "Latitude: %.6f\nLongitude: %.6f", coordinate.latitude, coordinate.longitude),
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            present(alert, animated: true)
        }
    }
}

// MARK: - MKMapViewDelegate
extension LocationTrackerViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        
        let identifier = "LocationAnnotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
    
    private func updateBatteryStatus() {
        let isLowPowerMode = locationManager.getLowPowerModeStatus()
        if isLowPowerMode {
            batteryOptimizationLabel.text = "🔋 Low Power Mode: ENABLED"
            batteryOptimizationLabel.textColor = .systemOrange
        } else {
            batteryOptimizationLabel.text = "✅ Low Power Mode: Disabled"
            batteryOptimizationLabel.textColor = .systemGreen
        }
    }
    
    private func showLowPowerModeTest() {
        let isLowPowerMode = locationManager.getLowPowerModeStatus()
        let statusText = isLowPowerMode ? "ENABLED" : "Disabled"
        let color = isLowPowerMode ? "Orange" : "Green"
        
        let alert = UIAlertController(
            title: "Low Power Mode Test",
            message: "Current Status: \(statusText) (\(color))\n\nTo test Low Power Mode:\n\n📱 iOS Simulator:\n• Device menu → Low Power Mode\n• Or Cmd+Shift+L\n\n📱 Physical Device:\n• Settings → Battery → Low Power Mode\n\nWatch the Xcode console for real-time updates!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Refresh Status", style: .default) { [weak self] _ in
            self?.updateBatteryStatus()
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showBackgroundTrackingStatus() {
        let status = locationManager.getBackgroundTrackingStatus()
        let alert = UIAlertController(title: "Background Tracking Status", message: status, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
}

// MARK: - Custom Annotation
class LocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        super.init()
    }
}
