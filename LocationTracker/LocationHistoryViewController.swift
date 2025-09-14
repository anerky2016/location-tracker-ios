import UIKit
import CoreLocation
import MapKit
import Combine

class LocationHistoryViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var statsLabel: UILabel!
    
    private let locationManager = LocationManager.shared
    private var locationHistory: [Location] = []
    private var filteredHistory: [Location] = []
    private var isShowingMap = false
    
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
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        // Initially hide map
        mapView.isHidden = true
        
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
        isShowingMap = segmentedControl.selectedSegmentIndex == 1
        
        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
            self.tableView.isHidden = self.isShowingMap
            self.mapView.isHidden = !self.isShowingMap
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
