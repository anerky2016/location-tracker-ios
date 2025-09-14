import UIKit
import CoreLocation
import MapKit
import Combine

class LocationHistoryViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var statsLabel: UILabel!
    
    // Time Machine UI Elements
    @IBOutlet weak var timeMachineContainer: UIView!
    @IBOutlet weak var timeRangeLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var speedSlider: UISlider!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var locationCountLabel: UILabel!
    
    private let locationManager = LocationManager.shared
    private var locationHistory: [Location] = []
    private var filteredHistory: [Location] = []
    private var isShowingMap = false
    
    // Time Machine properties
    private var timeMachineLocations: [Location] = []
    private var currentLocationIndex = 0
    private var replayTimer: Timer?
    private var isPlaying = false
    private var replaySpeed: Double = 1.0
    private var startDate: Date?
    private var endDate: Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupMapView()
        loadLocationHistory()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadLocationHistory()
    }
    
    private func setupUI() {
        title = "Location History"
        
        // Setup navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Filter",
            style: .plain,
            target: self,
            action: #selector(showFilterOptions)
        )
        
        // Setup segmented control
        segmentedControl.setTitle("List", forSegmentAt: 0)
        segmentedControl.setTitle("Map", forSegmentAt: 1)
        segmentedControl.setTitle("🕰️ Time Machine", forSegmentAt: 2)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        // Initially hide map and time machine
        mapView.isHidden = true
        timeMachineContainer.isHidden = true
        
        setupTimeMachineUI()
        
        updateStats()
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LocationCell")
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
    }
    
    private func loadLocationHistory() {
        locationHistory = locationManager.getLocationHistory(limit: 1000)
        filteredHistory = locationHistory
        updateStats()
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.updateMapWithHistory()
        }
    }
    
    private func updateStats() {
        let totalLocations = locationHistory.count
        let filteredLocations = filteredHistory.count
        
        if totalLocations > 0 {
            let firstLocation = locationHistory.last?.timestamp ?? Date()
            let lastLocation = locationHistory.first?.timestamp ?? Date()
            
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            
            statsLabel.text = "Total: \(totalLocations) locations | Showing: \(filteredLocations) | From: \(formatter.string(from: firstLocation)) to \(formatter.string(from: lastLocation))"
        } else {
            statsLabel.text = "No location history available"
        }
    }
    
    private func updateMapWithHistory() {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        for (index, location) in filteredHistory.prefix(100).enumerated() {
            let annotation = LocationAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                title: "Location \(index + 1)",
                subtitle: DateFormatter.localizedString(from: location.timestamp ?? Date(), dateStyle: .short, timeStyle: .short)
            )
            mapView.addAnnotation(annotation)
        }
        
        // Fit map to show all annotations
        if !filteredHistory.isEmpty {
            let coordinates = filteredHistory.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let region = MKCoordinateRegion(coordinates: coordinates)
            mapView.setRegion(region, animated: true)
        }
    }
    
    @objc private func segmentChanged() {
        let selectedIndex = segmentedControl.selectedSegmentIndex
        
        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
            // Hide all views first
            self.tableView.isHidden = true
            self.mapView.isHidden = true
            self.timeMachineContainer.isHidden = true
            
            switch selectedIndex {
            case 0: // List
                self.tableView.isHidden = false
                self.isShowingMap = false
            case 1: // Map
                self.mapView.isHidden = false
                self.isShowingMap = true
                self.updateMapWithHistory()
            case 2: // Time Machine
                self.timeMachineContainer.isHidden = false
                self.mapView.isHidden = false
                self.isShowingMap = true
                self.setupTimeMachineData()
                self.updateTimeMachineMap()
            default:
                break
            }
        }
    }
    
    @objc private func showFilterOptions() {
        let alert = UIAlertController(title: "Filter Options", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Show All", style: .default) { [weak self] _ in
            self?.filterHistory(by: .all)
        })
        
        alert.addAction(UIAlertAction(title: "Last 24 Hours", style: .default) { [weak self] _ in
            self?.filterHistory(by: .last24Hours)
        })
        
        alert.addAction(UIAlertAction(title: "Last 7 Days", style: .default) { [weak self] _ in
            self?.filterHistory(by: .last7Days)
        })
        
        alert.addAction(UIAlertAction(title: "Last 30 Days", style: .default) { [weak self] _ in
            self?.filterHistory(by: .last30Days)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func filterHistory(by filter: HistoryFilter) {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
        case .all:
            filteredHistory = locationHistory
        case .last24Hours:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            filteredHistory = locationHistory.filter { ($0.timestamp ?? Date()) >= yesterday }
        case .last7Days:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            filteredHistory = locationHistory.filter { ($0.timestamp ?? Date()) >= weekAgo }
        case .last30Days:
            let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filteredHistory = locationHistory.filter { ($0.timestamp ?? Date()) >= monthAgo }
        }
        
        updateStats()
        tableView.reloadData()
        updateMapWithHistory()
    }
}

// MARK: - UITableViewDataSource
extension LocationHistoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredHistory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)
        let location = filteredHistory[indexPath.row]
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        cell.textLabel?.text = String(format: "%.6f, %.6f", location.latitude, location.longitude)
        cell.detailTextLabel?.text = formatter.string(from: location.timestamp ?? Date())
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LocationHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let location = filteredHistory[indexPath.row]
        showLocationDetails(location)
    }
    
    private func showLocationDetails(_ location: Location) {
        let alert = UIAlertController(
            title: "Location Details",
            message: String(format: """
            Latitude: %.6f
            Longitude: %.6f
            Altitude: %.2f m
            Accuracy: %.2f m
            Speed: %.2f m/s
            Course: %.2f°
            Time: %@
            """,
            location.latitude,
            location.longitude,
            location.altitude,
            location.horizontalAccuracy,
            location.speed,
            location.course,
            DateFormatter.localizedString(from: location.timestamp ?? Date(), dateStyle: .full, timeStyle: .full)
            ),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Show on Map", style: .default) { [weak self] _ in
            self?.showLocationOnMap(location)
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showLocationOnMap(_ location: Location) {
        segmentedControl.selectedSegmentIndex = 1
        segmentChanged()
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        mapView.setRegion(region, animated: true)
    }
}

// MARK: - MKMapViewDelegate
extension LocationHistoryViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        
        // Handle Time Machine annotations
        if let timeMachineAnnotation = annotation as? TimeMachineAnnotation {
            let identifier = "TimeMachineAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Color code the annotations
            if let markerView = annotationView as? MKMarkerAnnotationView {
                if timeMachineAnnotation.isCurrent {
                    markerView.markerTintColor = .systemRed
                    markerView.glyphText = "📍"
                } else if timeMachineAnnotation.index < currentLocationIndex {
                    markerView.markerTintColor = .systemBlue
                    markerView.glyphText = "•"
                } else {
                    markerView.markerTintColor = .systemGray
                    markerView.glyphText = "•"
                }
            }
            
            return annotationView
        }
        
        // Handle regular location annotations
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
}

// MARK: - Time Machine Methods
extension LocationHistoryViewController {
    
    private func setupTimeMachineUI() {
        // Setup Time Machine controls
        playPauseButton.setTitle("▶️ Play", for: .normal)
        playPauseButton.backgroundColor = .systemGreen
        playPauseButton.layer.cornerRadius = 8
        
        speedSlider.minimumValue = 0.1
        speedSlider.maximumValue = 10.0
        speedSlider.value = 1.0
        speedSlider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        
        progressSlider.addTarget(self, action: #selector(progressChanged), for: .valueChanged)
        
        updateSpeedLabel()
        updateTimeMachineUI()
    }
    
    private func setupTimeMachineData() {
        // Use last 24 hours by default
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        timeMachineLocations = locationHistory.filter { location in
            guard let timestamp = location.timestamp else { return false }
            return timestamp >= yesterday
        }
        
        // Sort by timestamp
        timeMachineLocations.sort { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        startDate = yesterday
        endDate = Date()
        
        updateTimeMachineUI()
    }
    
    private func updateTimeMachineUI() {
        locationCountLabel.text = "\(timeMachineLocations.count) locations"
        
        if let start = startDate, let end = endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            timeRangeLabel.text = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            timeRangeLabel.text = "Last 24 hours"
        }
        
        // Update progress slider
        if !timeMachineLocations.isEmpty {
            progressSlider.maximumValue = Float(timeMachineLocations.count - 1)
            progressSlider.value = Float(currentLocationIndex)
        }
        
        updateCurrentTimeLabel()
    }
    
    private func updateCurrentTimeLabel() {
        if currentLocationIndex < timeMachineLocations.count {
            let location = timeMachineLocations[currentLocationIndex]
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            currentTimeLabel.text = formatter.string(from: location.timestamp ?? Date())
        } else {
            currentTimeLabel.text = "No location"
        }
    }
    
    private func updateSpeedLabel() {
        speedLabel.text = String(format: "%.1fx", replaySpeed)
    }
    
    private func updateTimeMachineMap() {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Add all locations as dots
        for (index, location) in timeMachineLocations.enumerated() {
            let annotation = TimeMachineAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                title: "Location \(index + 1)",
                subtitle: DateFormatter.localizedString(from: location.timestamp ?? Date(), dateStyle: .short, timeStyle: .short),
                index: index,
                isCurrent: index == currentLocationIndex
            )
            mapView.addAnnotation(annotation)
        }
        
        // Center map on current location or all locations
        if currentLocationIndex < timeMachineLocations.count {
            let currentLocation = timeMachineLocations[currentLocationIndex]
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: currentLocation.latitude, longitude: currentLocation.longitude),
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)
        } else if !timeMachineLocations.isEmpty {
            let coordinates = timeMachineLocations.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let region = MKCoordinateRegion(coordinates: coordinates)
            mapView.setRegion(region, animated: true)
        }
    }
    
    @IBAction func playPauseButtonTapped(_ sender: UIButton) {
        if isPlaying {
            pauseReplay()
        } else {
            startReplay()
        }
    }
    
    @objc private func speedChanged() {
        replaySpeed = Double(speedSlider.value)
        updateSpeedLabel()
        
        // Restart timer with new speed if playing
        if isPlaying {
            stopReplay()
            startReplay()
        }
    }
    
    @objc private func progressChanged() {
        currentLocationIndex = Int(progressSlider.value)
        updateTimeMachineUI()
        updateTimeMachineMap()
    }
    
    private func startReplay() {
        guard !timeMachineLocations.isEmpty else { return }
        
        isPlaying = true
        playPauseButton.setTitle("⏸️ Pause", for: .normal)
        playPauseButton.backgroundColor = .systemOrange
        
        // Calculate interval based on speed (faster speed = shorter interval)
        let baseInterval: TimeInterval = 0.5 // 0.5 seconds per location at 1x speed
        let interval = baseInterval / replaySpeed
        
        replayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceToNextLocation()
        }
    }
    
    private func pauseReplay() {
        isPlaying = false
        playPauseButton.setTitle("▶️ Play", for: .normal)
        playPauseButton.backgroundColor = .systemGreen
        replayTimer?.invalidate()
        replayTimer = nil
    }
    
    private func stopReplay() {
        pauseReplay()
        currentLocationIndex = 0
        updateTimeMachineUI()
        updateTimeMachineMap()
    }
    
    private func advanceToNextLocation() {
        currentLocationIndex += 1
        
        if currentLocationIndex >= timeMachineLocations.count {
            // Reached the end, stop replay
            stopReplay()
            return
        }
        
        updateTimeMachineUI()
        updateTimeMachineMap()
    }
}


// MARK: - Helper Types
enum HistoryFilter {
    case all
    case last24Hours
    case last7Days
    case last30Days
}

// MARK: - MKCoordinateRegion Extension
extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion()
            return
        }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01),
            longitudeDelta: max(maxLon - minLon, 0.01)
        )
        
        self = MKCoordinateRegion(center: center, span: span)
    }
}
