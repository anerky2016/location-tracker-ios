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
    @IBOutlet weak var debugInfoLabel: UILabel!
    
    private let locationManager = LocationManager.shared
    private let paginatedManager = PaginatedLocationManager(pageSize: 50)
    
    // Memory-optimized data storage
    private var loadedLocations: [Location] = []
    private var filteredHistory: [Location] = []
    private var isShowingMap = false
    
    // Infinite scroll properties
    private var isLoadingMore = false
    private var hasMoreData = true
    
    // Expandable rows properties
    private var expandedRows: Set<Int> = []
    
    // Time Machine properties - using lightweight structs
    private var timeMachineLocations: [TimeMachineLocation] = []
    private var currentLocationIndex = 0
    private var replayTimer: Timer?
    private var isPlaying = false
    private var replaySpeed: Double = 1.0
    private var startDate: Date?
    private var endDate: Date?
    
    // Navigation-style animation properties
    private var currentMarker: MKAnnotationView?
    private var routePolyline: MKPolyline?
    private var animationTimer: Timer?
    private var isAnimating = false
    private var animationProgress: Double = 0.0
    private var animationStartLocation: CLLocationCoordinate2D?
    private var animationEndLocation: CLLocationCoordinate2D?
    private var initialZoomLevel: MKCoordinateSpan?
    
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
        title = "📊 Location History"
        
        // Setup modern navigation bar
        setupModernNavigationBar()
        
        // Setup modern segmented control
        setupModernSegmentedControl()
        
        // Setup modern table view
        setupModernTableView()
        
        // Setup modern map view
        setupModernMapView()
        
        // Initially hide map and time machine
        mapView.isHidden = true
        timeMachineContainer.isHidden = true
        
        setupTimeMachineUI()
        
        updateStats()
    }
    
    private func setupModernNavigationBar() {
        // Modern navigation bar styling
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        // Modern filter button with SF Symbol
        let filterButton = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(showFilterOptions)
        )
        filterButton.tintColor = .systemBlue
        navigationItem.rightBarButtonItem = filterButton
    }
    
    private func setupModernSegmentedControl() {
        // Modern segmented control styling
        segmentedControl.setTitle("📋 List", forSegmentAt: 0)
        segmentedControl.setTitle("🗺️ Map", forSegmentAt: 1)
        segmentedControl.setTitle("🕰️ Time Machine", forSegmentAt: 2)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        // Modern styling
        segmentedControl.backgroundColor = UIColor.systemGray6
        segmentedControl.selectedSegmentTintColor = UIColor.systemBlue
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 16, weight: .medium)
        ], for: .normal)
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ], for: .selected)
        
        // Add corner radius and shadow
        segmentedControl.layer.cornerRadius = 12
        segmentedControl.layer.shadowColor = UIColor.black.cgColor
        segmentedControl.layer.shadowOffset = CGSize(width: 0, height: 2)
        segmentedControl.layer.shadowRadius = 4
        segmentedControl.layer.shadowOpacity = 0.1
    }
    
    private func setupModernTableView() {
        // Modern table view styling
        tableView.backgroundColor = UIColor.systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        
        // Add subtle shadow
        tableView.layer.shadowColor = UIColor.black.cgColor
        tableView.layer.shadowOffset = CGSize(width: 0, height: 2)
        tableView.layer.shadowRadius = 8
        tableView.layer.shadowOpacity = 0.05
    }
    
    private func setupModernMapView() {
        // Modern map view styling
        mapView.layer.cornerRadius = 16
        mapView.layer.shadowColor = UIColor.black.cgColor
        mapView.layer.shadowOffset = CGSize(width: 0, height: 4)
        mapView.layer.shadowRadius = 12
        mapView.layer.shadowOpacity = 0.15
        
        // Modern map features
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsBuildings = true
        mapView.showsTraffic = false
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LocationCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LoadingCell")
        
        // Set row height to accommodate detailed information
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        
        // Remove separator lines for cleaner look
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
    }
    
    private func loadLocationHistory() {
        // Reset pagination and load first page
        paginatedManager.resetPagination()
        loadedLocations = paginatedManager.loadNextPage()
        filteredHistory = loadedLocations
        
        // Reset infinite scroll state
        isLoadingMore = false
        hasMoreData = paginatedManager.hasMorePages
        
        // Reset expanded rows when loading new data
        expandedRows.removeAll()
        
        updateStats()
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.updateMapWithHistory()
        }
        
        print("📊 Memory-optimized loading: \(loadedLocations.count) locations loaded (page 1)")
    }
    
    private func loadMoreLocations() {
        guard !isLoadingMore && hasMoreData else { return }
        
        isLoadingMore = true
        print("🔄 Loading more locations...")
        
        // Load next page in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let newLocations = self.paginatedManager.loadNextPage()
            
            DispatchQueue.main.async {
                if !newLocations.isEmpty {
                    // Append new locations to existing data
                    self.loadedLocations.append(contentsOf: newLocations)
                    self.filteredHistory.append(contentsOf: newLocations)
                    
                    // Update infinite scroll state
                    self.hasMoreData = self.paginatedManager.hasMorePages
                    self.isLoadingMore = false
                    
                    // Reload table view with animation
                    let startIndex = self.loadedLocations.count - newLocations.count
                    let endIndex = self.loadedLocations.count - 1
                    let indexPaths = (startIndex...endIndex).map { IndexPath(row: $0, section: 0) }
                    
                    self.tableView.insertRows(at: indexPaths, with: .fade)
                    self.updateStats()
                    self.updateMapWithHistory()
                    
                    print("✅ Loaded \(newLocations.count) more locations. Total: \(self.loadedLocations.count)")
                } else {
                    // No more data available
                    self.hasMoreData = false
                    self.isLoadingMore = false
                    print("📄 No more locations to load")
                }
            }
        }
    }
    
    private func updateStats() {
        let totalLocations = paginatedManager.totalLocationCount
        let loadedCount = paginatedManager.loadedLocationCount
        let filteredLocations = filteredHistory.count
        
        if totalLocations > 0 {
            let firstLocation = loadedLocations.isEmpty ? Date() : (loadedLocations.last?.timestamp ?? Date())
            let lastLocation = loadedLocations.isEmpty ? Date() : (loadedLocations.first?.timestamp ?? Date())
            
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            
            let paginationInfo = paginatedManager.hasMorePages ? " (more available)" : ""
            statsLabel.text = "Total: \(totalLocations) locations | Loaded: \(loadedCount)\(paginationInfo) | Showing: \(filteredLocations) | From: \(formatter.string(from: firstLocation)) to \(formatter.string(from: lastLocation))"
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
                
                // Ensure map is visible before setting zoom level
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.setOptimalZoomLevel()
                }
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
            filteredHistory = loadedLocations
        case .last24Hours:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            filteredHistory = loadedLocations.filter { ($0.timestamp ?? Date()) >= yesterday }
        case .last7Days:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            filteredHistory = loadedLocations.filter { ($0.timestamp ?? Date()) >= weekAgo }
        case .last30Days:
            let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filteredHistory = loadedLocations.filter { ($0.timestamp ?? Date()) >= monthAgo }
        }
        
        updateStats()
        tableView.reloadData()
        updateMapWithHistory()
    }
}

// MARK: - UITableViewDataSource
extension LocationHistoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Add 1 for loading cell if we're loading more data
        return filteredHistory.count + (isLoadingMore ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Show loading cell if this is the last row and we're loading more data
        if isLoadingMore && indexPath.row == filteredHistory.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath)
            cell.textLabel?.text = "Loading more locations..."
            cell.textLabel?.textColor = .systemBlue
            cell.textLabel?.textAlignment = .center
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .none
            
            // Add activity indicator
            let activityIndicator = UIActivityIndicatorView(style: .medium)
            activityIndicator.startAnimating()
            cell.accessoryView = activityIndicator
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)
        let location = filteredHistory[indexPath.row]
        let isExpanded = expandedRows.contains(indexPath.row)
        
        // Clear previous content
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Format date and time
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let dateFormatterShort = DateFormatter()
        dateFormatterShort.dateFormat = "MMM dd, yyyy"
        
        let timestamp = location.timestamp ?? Date()
        let dateString = dateFormatterShort.string(from: timestamp)
        let timeString = timeFormatter.string(from: timestamp)
        
        // Create main container view with modern styling
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        containerView.layer.shadowOpacity = 0.08
        cell.contentView.addSubview(containerView)
        
        // Main title label
        let titleLabel = UILabel()
        titleLabel.text = "\(dateString) at \(timeString)"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Basic info label
        let basicInfoLabel = UILabel()
        let coordinateString = String(format: "%.6f, %.6f", location.latitude, location.longitude)
        let accuracyString = String(format: "±%.0fm", location.horizontalAccuracy)
        let speedString = location.speed > 0 ? String(format: "%.1f m/s", location.speed) : "Stationary"
        let altitudeString = String(format: "%.0fm", location.altitude)
        
        basicInfoLabel.text = "📍 \(coordinateString) • \(accuracyString) • \(speedString) • \(altitudeString)"
        basicInfoLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        basicInfoLabel.textColor = .secondaryLabel
        basicInfoLabel.numberOfLines = 2
        basicInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(basicInfoLabel)
        
        // Expand/collapse indicator
        let indicatorLabel = UILabel()
        indicatorLabel.text = isExpanded ? "▼" : "▶"
        indicatorLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        indicatorLabel.textColor = .systemBlue
        indicatorLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(indicatorLabel)
        
        // Set up constraints for modern layout with proper spacing
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: indicatorLabel.leadingAnchor, constant: -8),
            
            basicInfoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            basicInfoLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            basicInfoLabel.trailingAnchor.constraint(equalTo: indicatorLabel.leadingAnchor, constant: -8),
            
            indicatorLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            indicatorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            indicatorLabel.widthAnchor.constraint(equalToConstant: 20)
        ])
        
        // Add detailed information if expanded
        if isExpanded {
            // Create modern details container
            let detailsContainer = UIView()
            detailsContainer.backgroundColor = UIColor.systemGray6
            detailsContainer.layer.cornerRadius = 8
            detailsContainer.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(detailsContainer)
            
            let detailsLabel = UILabel()
            detailsLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            detailsLabel.textColor = .secondaryLabel
            detailsLabel.numberOfLines = 0
            detailsLabel.translatesAutoresizingMaskIntoConstraints = false
            
            // Create detailed information with modern formatting
            let courseString = String(format: "%.1f°", location.course)
            let courseAccuracyString = String(format: "±%.1f°", location.courseAccuracy)
            let speedAccuracyString = String(format: "±%.1f m/s", location.speedAccuracy)
            let verticalAccuracyString = String(format: "±%.0fm", location.verticalAccuracy)
            
            let detailsText = """
            📍 Coordinates: \(coordinateString)
            🎯 Horizontal Accuracy: \(accuracyString)
            📏 Vertical Accuracy: \(verticalAccuracyString)
            🚗 Speed: \(speedString) (\(speedAccuracyString))
            🧭 Course: \(courseString) (\(courseAccuracyString))
            ⛰️ Altitude: \(altitudeString)
            🕐 Timestamp: \(DateFormatter.localizedString(from: timestamp, dateStyle: .full, timeStyle: .full))
            """
            
            detailsLabel.text = detailsText
            detailsContainer.addSubview(detailsLabel)
            
            // Update constraints to include modern details container
            NSLayoutConstraint.activate([
                detailsContainer.topAnchor.constraint(equalTo: basicInfoLabel.bottomAnchor, constant: 12),
                detailsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                detailsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
                detailsContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
                
                detailsLabel.topAnchor.constraint(equalTo: detailsContainer.topAnchor, constant: 12),
                detailsLabel.leadingAnchor.constraint(equalTo: detailsContainer.leadingAnchor, constant: 12),
                detailsLabel.trailingAnchor.constraint(equalTo: detailsContainer.trailingAnchor, constant: -12),
                detailsLabel.bottomAnchor.constraint(equalTo: detailsContainer.bottomAnchor, constant: -12)
            ])
        } else {
            // Set bottom constraint for basic info when not expanded
            basicInfoLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
        }
        
        // Remove any previous accessory views
        cell.accessoryType = .none
        cell.accessoryView = nil
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LocationHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Don't allow selection of loading cell
        if isLoadingMore && indexPath.row == filteredHistory.count {
            return
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Toggle expanded state
        let rowIndex = indexPath.row
        if expandedRows.contains(rowIndex) {
            expandedRows.remove(rowIndex)
        } else {
            expandedRows.insert(rowIndex)
        }
        
        // Animate the row height change with modern spring animation
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: [.curveEaseInOut], animations: {
            tableView.beginUpdates()
            tableView.endUpdates()
        })
        
        // Scroll to keep the expanded row visible
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Check if user has scrolled near the bottom
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        // Trigger infinite scroll when user is 100 points from the bottom
        if offsetY > contentHeight - height - 100 {
            loadMoreLocations()
        }
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
        
        // Handle Current Location annotation (for smooth animation)
        if annotation is CurrentLocationAnnotation {
            let identifier = "CurrentLocationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                // Create a more sophisticated marker with multiple layers
                let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
                containerView.backgroundColor = .clear
                
                // Outer pulsing ring
                let outerRing = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
                outerRing.backgroundColor = .clear
                outerRing.layer.cornerRadius = 15
                outerRing.layer.borderWidth = 2
                outerRing.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.6).cgColor
                
                // Inner solid dot
                let innerDot = UIView(frame: CGRect(x: 8, y: 8, width: 14, height: 14))
                innerDot.backgroundColor = .systemRed
                innerDot.layer.cornerRadius = 7
                innerDot.layer.borderWidth = 2
                innerDot.layer.borderColor = UIColor.white.cgColor
                innerDot.layer.shadowColor = UIColor.black.cgColor
                innerDot.layer.shadowOffset = CGSize(width: 0, height: 1)
                innerDot.layer.shadowRadius = 2
                innerDot.layer.shadowOpacity = 0.4
                
                containerView.addSubview(outerRing)
                containerView.addSubview(innerDot)
                
                // Smooth pulsing animation for outer ring
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.duration = 1.5
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.4
                pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                pulseAnimation.autoreverses = true
                pulseAnimation.repeatCount = .infinity
                outerRing.layer.add(pulseAnimation, forKey: "pulse")
                
                // Subtle breathing animation for inner dot
                let breatheAnimation = CABasicAnimation(keyPath: "opacity")
                breatheAnimation.duration = 2.0
                breatheAnimation.fromValue = 1.0
                breatheAnimation.toValue = 0.7
                breatheAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                breatheAnimation.autoreverses = true
                breatheAnimation.repeatCount = .infinity
                innerDot.layer.add(breatheAnimation, forKey: "breathe")
                
                annotationView?.addSubview(containerView)
                annotationView?.frame = containerView.frame
                annotationView?.centerOffset = CGPoint(x: 0, y: -15) // Center the marker properly
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
        
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
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 4.0
            renderer.lineCap = .round
            renderer.lineJoin = .round
            renderer.alpha = 0.8
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - Time Machine Methods
extension LocationHistoryViewController {
    
    private func setupTimeMachineUI() {
        // Setup Time Machine controls with navigation-style design
        playPauseButton.setTitle("▶️ Play", for: .normal)
        playPauseButton.backgroundColor = .systemGreen
        playPauseButton.layer.cornerRadius = 8
        playPauseButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        speedSlider.minimumValue = 0.1
        speedSlider.maximumValue = 10.0
        speedSlider.value = 1.0
        speedSlider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        
        progressSlider.addTarget(self, action: #selector(progressChanged), for: .valueChanged)
        
        // Style the labels
        timeRangeLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        timeRangeLabel.textColor = .systemBlue
        
        locationCountLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        locationCountLabel.textColor = .systemGray
        
        currentTimeLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        currentTimeLabel.textColor = .systemRed
        
        speedLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        speedLabel.textColor = .systemBlue
        
        updateSpeedLabel()
        updateTimeMachineUI()
    }
    
    private func setupTimeMachineData() {
        // Use last 24 hours by default
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        // Get locations in date range using paginated manager
        let locationsInRange = paginatedManager.getLocationsInDateRange(from: yesterday, to: Date())
        
        // Convert to lightweight TimeMachineLocation structs
        timeMachineLocations = locationsInRange.enumerated().map { index, location in
            TimeMachineLocation.from(location, index: index)
        }
        
        // Sort by timestamp
        timeMachineLocations.sort { $0.timestamp < $1.timestamp }
        
        startDate = yesterday
        endDate = Date()
        
        updateTimeMachineUI()
        updateDebugInfo()
    }
    
    private func setOptimalZoomLevel() {
        guard !timeMachineLocations.isEmpty else { return }
        
        // Calculate the bounding box of all locations
        let coordinates = timeMachineLocations.map { $0.coordinate }
        
        // Find min/max coordinates
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        // Calculate center point
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // Calculate span with more padding for better overview
        let latDelta = (maxLat - minLat) * 1.5 // 50% padding for better overview
        let lonDelta = (maxLon - minLon) * 1.5 // 50% padding for better overview
        
        // Apply zoom-out factor for better viewing experience
        let zoomFactor = 1.2 // 20% more zoom-out for better experience
        let adjustedLatDelta = latDelta * zoomFactor
        let adjustedLonDelta = lonDelta * zoomFactor
        
        // Larger minimum span for better overview
        let minSpan = 0.001 // Larger minimum span for better overview
        let finalLatDelta = max(adjustedLatDelta, minSpan)
        let finalLonDelta = max(adjustedLonDelta, minSpan)
        
        let span = MKCoordinateSpan(latitudeDelta: finalLatDelta, longitudeDelta: finalLonDelta)
        let region = MKCoordinateRegion(center: center, span: span)
        
        // Store the optimal zoom level
        initialZoomLevel = span
        
        // Set the optimal zoom level with smooth animation
        mapView.setRegion(region, animated: true)
        
        print("🎯 Set optimal zoom level for \(timeMachineLocations.count) locations")
        print("📍 Center: \(centerLat), \(centerLon)")
        print("📏 Span: \(finalLatDelta), \(finalLonDelta)")
        print("🗺️ Map region set with animated: true")
        
        // Update debug info after zoom level is set
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateDebugInfo()
        }
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
        updateDebugInfo()
    }
    
    private func updateCurrentTimeLabel() {
        if currentLocationIndex < timeMachineLocations.count {
            let location = timeMachineLocations[currentLocationIndex]
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            currentTimeLabel.text = formatter.string(from: location.timestamp)
        } else {
            currentTimeLabel.text = "No location"
        }
    }
    
    private func updateSpeedLabel() {
        speedLabel.text = String(format: "%.1fx", replaySpeed)
    }
    
    private func updateDebugInfo() {
        let currentRegion = mapView.region
        let center = currentRegion.center
        let span = currentRegion.span
        
        let debugText = """
        🗺️ DEBUG INFO:
        Center: \(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude))
        Span: \(String(format: "%.6f", span.latitudeDelta)) x \(String(format: "%.6f", span.longitudeDelta))
        Locations: \(timeMachineLocations.count)
        Current Index: \(currentLocationIndex)
        Playing: \(isPlaying ? "Yes" : "No")
        Speed: \(String(format: "%.1fx", replaySpeed))
        """
        
        debugInfoLabel.text = debugText
    }
    
    private func updateTimeMachineMap() {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Remove existing route line
        if let polyline = routePolyline {
            mapView.removeOverlay(polyline)
        }
        
        // Add route line if we have multiple locations
        if timeMachineLocations.count > 1 {
            let coordinates = timeMachineLocations.map { $0.coordinate }
            routePolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            if let polyline = routePolyline {
                mapView.addOverlay(polyline)
            }
        }
        
        // Add all locations as dots
        for (index, location) in timeMachineLocations.enumerated() {
            let annotation = TimeMachineAnnotation(
                coordinate: location.coordinate,
                title: "Location \(index + 1)",
                subtitle: DateFormatter.localizedString(from: location.timestamp, dateStyle: .short, timeStyle: .short),
                index: index,
                isCurrent: index == currentLocationIndex
            )
            mapView.addAnnotation(annotation)
        }
        
        // Add current location marker with special styling
        if currentLocationIndex < timeMachineLocations.count {
            let currentLocation = timeMachineLocations[currentLocationIndex]
            let currentAnnotation = CurrentLocationAnnotation(
                coordinate: currentLocation.coordinate,
                title: "Current Position",
                subtitle: DateFormatter.localizedString(from: currentLocation.timestamp, dateStyle: .short, timeStyle: .short)
            )
            mapView.addAnnotation(currentAnnotation)
            
            // Center on current location without changing zoom (zoom already set optimally)
            let currentCoord = currentLocation.coordinate
            mapView.setCenter(currentCoord, animated: true)
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
        updateDebugInfo()
        
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
        updateDebugInfo()
    }
    
    private func startReplay() {
        guard !timeMachineLocations.isEmpty else { return }
        
        isPlaying = true
        playPauseButton.setTitle("⏸️ Pause", for: .normal)
        playPauseButton.backgroundColor = .systemOrange
        updateDebugInfo()
        
        // Wait for zoom transition to complete before starting navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.isPlaying else { return }
            
            // Ultra-responsive timing - very short base interval for ultra-smooth feel
            let baseInterval: TimeInterval = 0.6 // 0.6 seconds per location at 1x speed for ultra-smooth feel
            let interval = baseInterval / self.replaySpeed
            
            self.replayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.advanceToNextLocationWithAnimation()
            }
        }
    }
    
    private func pauseReplay() {
        isPlaying = false
        playPauseButton.setTitle("▶️ Play", for: .normal)
        playPauseButton.backgroundColor = .systemGreen
        replayTimer?.invalidate()
        replayTimer = nil
        updateDebugInfo()
    }
    
    private func stopReplay() {
        pauseReplay()
        currentLocationIndex = 0
        updateTimeMachineUI()
        updateTimeMachineMap()
    }
    
    private func advanceToNextLocationWithAnimation() {
        guard currentLocationIndex + 1 < timeMachineLocations.count else {
            // Reached the end, stop replay
            stopReplay()
            return
        }
        
        let startLocation = timeMachineLocations[currentLocationIndex]
        let endLocation = timeMachineLocations[currentLocationIndex + 1]
        
        // Update UI immediately for better responsiveness
        currentLocationIndex += 1
        updateTimeMachineUI()
        
        // Start smooth animation between locations
        animateToNextLocation(from: startLocation, to: endLocation) { [weak self] in
            // Animation completed - update map to show final position
            self?.updateTimeMachineMap()
        }
    }
    
    private func animateToNextLocation(from startLocation: TimeMachineLocation, to endLocation: TimeMachineLocation, completion: @escaping () -> Void) {
        let startCoord = startLocation.coordinate
        let endCoord = endLocation.coordinate
        
        // Calculate distance for animation duration
        let distance = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
            .distance(from: CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude))
        
        // Ultra-smooth animation duration - very short and consistent
        let baseDuration = min(max(distance / 3000.0, 0.15), 0.6) // Much shorter for ultra-smooth feel
        let animationDuration = baseDuration / replaySpeed
        
        // Create ultra-smooth interpolated animation with maximum steps
        let steps = max(Int(distance / 20), 12) // Maximum steps for buttery smooth animation
        let stepDuration = animationDuration / Double(steps)
        
        // Create temporary annotation for smooth movement
        let tempAnnotation = CurrentLocationAnnotation(
            coordinate: startCoord,
            title: "Moving...",
            subtitle: nil
        )
        mapView.addAnnotation(tempAnnotation)
        
        // Smooth step-by-step animation
        animateMarkerStep(annotation: tempAnnotation, 
                         from: startCoord, 
                         to: endCoord, 
                         currentStep: 0, 
                         totalSteps: steps, 
                         stepDuration: stepDuration,
                         completion: {
            // Remove temporary annotation
            self.mapView.removeAnnotation(tempAnnotation)
            completion()
        })
    }
    
    private func animateMarkerStep(annotation: CurrentLocationAnnotation,
                                 from startCoord: CLLocationCoordinate2D,
                                 to endCoord: CLLocationCoordinate2D,
                                 currentStep: Int,
                                 totalSteps: Int,
                                 stepDuration: TimeInterval,
                                 completion: @escaping () -> Void) {
        
        guard currentStep <= totalSteps else {
            completion()
            return
        }
        
        // Calculate interpolated coordinate
        let progress = Double(currentStep) / Double(totalSteps)
        let lat = startCoord.latitude + (endCoord.latitude - startCoord.latitude) * progress
        let lon = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * progress
        let currentCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        // Update annotation coordinate
        annotation.coordinate = currentCoord
        
        // Ultra-smooth map centering without any zoom changes (minimal updates)
        if currentStep % 20 == 0 || currentStep == totalSteps {
            // Use setCenter for smooth centering without any zoom effects
            mapView.setCenter(currentCoord, animated: true)
        }
        
        // Schedule next step
        DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
            self.animateMarkerStep(annotation: annotation,
                                 from: startCoord,
                                 to: endCoord,
                                 currentStep: currentStep + 1,
                                 totalSteps: totalSteps,
                                 stepDuration: stepDuration,
                                 completion: completion)
        }
    }
}


// MARK: - Helper Types
enum HistoryFilter {
    case all
    case last24Hours
    case last7Days
    case last30Days
}

// MARK: - Custom Annotation Classes
class CurrentLocationAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        super.init()
    }
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
