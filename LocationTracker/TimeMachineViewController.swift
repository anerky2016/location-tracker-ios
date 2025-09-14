import UIKit
import MapKit
import CoreLocation

class TimeMachineViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var timeRangeLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var speedSlider: UISlider!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var locationCountLabel: UILabel!
    
    private let locationManager = LocationManager.shared
    private var filteredLocations: [Location] = []
    private var currentLocationIndex = 0
    private var replayTimer: Timer?
    private var isPlaying = false
    private var replaySpeed: Double = 1.0 // 1x speed by default
    
    // Time range for replay
    private var startDate: Date?
    private var endDate: Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMapView()
        loadLocationHistory()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopReplay()
    }
    
    private func setupUI() {
        title = "Time Machine"
        
        // Setup navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Time Range",
            style: .plain,
            target: self,
            action: #selector(showTimeRangePicker)
        )
        
        // Setup buttons
        playPauseButton.setTitle("▶️ Play", for: .normal)
        playPauseButton.backgroundColor = .systemGreen
        playPauseButton.layer.cornerRadius = 8
        
        // Setup sliders
        speedSlider.minimumValue = 0.1
        speedSlider.maximumValue = 10.0
        speedSlider.value = 1.0
        speedSlider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        
        progressSlider.addTarget(self, action: #selector(progressChanged), for: .valueChanged)
        
        updateSpeedLabel()
        updateUI()
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
    }
    
    private func loadLocationHistory() {
        let allLocations = locationManager.getLocationHistory(limit: 10000)
        
        if let start = startDate, let end = endDate {
            filteredLocations = allLocations.filter { location in
                guard let timestamp = location.timestamp else { return false }
                return timestamp >= start && timestamp <= end
            }
        } else {
            // If no time range set, use last 24 hours
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            filteredLocations = allLocations.filter { location in
                guard let timestamp = location.timestamp else { return false }
                return timestamp >= yesterday
            }
        }
        
        // Sort by timestamp
        filteredLocations.sort { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        updateUI()
        updateMapWithLocations()
    }
    
    private func updateUI() {
        locationCountLabel.text = "\(filteredLocations.count) locations"
        
        if let start = startDate, let end = endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            timeRangeLabel.text = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            timeRangeLabel.text = "Last 24 hours"
        }
        
        // Update progress slider
        if !filteredLocations.isEmpty {
            progressSlider.maximumValue = Float(filteredLocations.count - 1)
            progressSlider.value = Float(currentLocationIndex)
        }
        
        updateCurrentTimeLabel()
    }
    
    private func updateCurrentTimeLabel() {
        if currentLocationIndex < filteredLocations.count {
            let location = filteredLocations[currentLocationIndex]
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
    
    private func updateMapWithLocations() {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Add all locations as dots
        for (index, location) in filteredLocations.enumerated() {
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
        if currentLocationIndex < filteredLocations.count {
            let currentLocation = filteredLocations[currentLocationIndex]
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: currentLocation.latitude, longitude: currentLocation.longitude),
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)
        } else if !filteredLocations.isEmpty {
            let coordinates = filteredLocations.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let region = MKCoordinateRegion(coordinates: coordinates)
            mapView.setRegion(region, animated: true)
        }
    }
    
    @objc private func showTimeRangePicker() {
        let alert = UIAlertController(title: "Select Time Range", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Last Hour", style: .default) { [weak self] _ in
            self?.setTimeRange(hours: 1)
        })
        
        alert.addAction(UIAlertAction(title: "Last 6 Hours", style: .default) { [weak self] _ in
            self?.setTimeRange(hours: 6)
        })
        
        alert.addAction(UIAlertAction(title: "Last 24 Hours", style: .default) { [weak self] _ in
            self?.setTimeRange(hours: 24)
        })
        
        alert.addAction(UIAlertAction(title: "Last 7 Days", style: .default) { [weak self] _ in
            self?.setTimeRange(days: 7)
        })
        
        alert.addAction(UIAlertAction(title: "Custom Range", style: .default) { [weak self] _ in
            self?.showCustomTimeRangePicker()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func setTimeRange(hours: Int) {
        endDate = Date()
        startDate = Calendar.current.date(byAdding: .hour, value: -hours, to: endDate!)
        loadLocationHistory()
    }
    
    private func setTimeRange(days: Int) {
        endDate = Date()
        startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate!)
        loadLocationHistory()
    }
    
    private func showCustomTimeRangePicker() {
        // For now, use a simple alert. In a real app, you'd use a proper date picker
        let alert = UIAlertController(title: "Custom Time Range", message: "This would open a date picker in a real implementation", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
        updateUI()
        updateMapWithLocations()
    }
    
    private func startReplay() {
        guard !filteredLocations.isEmpty else { return }
        
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
        updateUI()
        updateMapWithLocations()
    }
    
    private func advanceToNextLocation() {
        currentLocationIndex += 1
        
        if currentLocationIndex >= filteredLocations.count {
            // Reached the end, stop replay
            stopReplay()
            return
        }
        
        updateUI()
        updateMapWithLocations()
    }
}

// MARK: - MKMapViewDelegate
extension TimeMachineViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        
        guard let timeMachineAnnotation = annotation as? TimeMachineAnnotation else { return nil }
        
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
}

// MARK: - Custom Annotation
class TimeMachineAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let index: Int
    let isCurrent: Bool
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, index: Int, isCurrent: Bool) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.index = index
        self.isCurrent = isCurrent
        super.init()
    }
}
