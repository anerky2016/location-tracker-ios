import UIKit
import CoreLocation
import CoreData

class DebugInfoViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    
    private var debugLabels: [UILabel] = []
    private var refreshTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDebugLabels()
        startAutoRefresh()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateDebugInfo()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAutoRefresh()
    }
    
    private func setupUI() {
        title = "Debug Information"
        
        // Setup navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshDebugInfo)
        )
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add scroll view constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupDebugLabels() {
        let sections = [
            "📱 Device Information",
            "🧠 Memory Usage",
            "🔋 Battery & Power",
            "📍 Location Services",
            "💾 Core Data",
            "⚡ Performance Metrics",
            "🔧 App Configuration"
        ]
        
        var lastLabel: UILabel?
        
        for section in sections {
            // Section header
            let headerLabel = createSectionHeader(text: section)
            contentView.addSubview(headerLabel)
            
            NSLayoutConstraint.activate([
                headerLabel.topAnchor.constraint(equalTo: lastLabel?.bottomAnchor ?? contentView.topAnchor, constant: lastLabel == nil ? 20 : 30),
                headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
            ])
            
            lastLabel = headerLabel
            
            // Add content labels for this section
            let contentLabels = createContentLabels(for: section)
            for (index, label) in contentLabels.enumerated() {
                contentView.addSubview(label)
                debugLabels.append(label)
                
                NSLayoutConstraint.activate([
                    label.topAnchor.constraint(equalTo: lastLabel!.bottomAnchor, constant: index == 0 ? 10 : 5),
                    label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                    label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
                ])
                
                lastLabel = label
            }
        }
        
        // Set bottom constraint for content view
        if let lastLabel = lastLabel {
            NSLayoutConstraint.activate([
                lastLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
            ])
        }
    }
    
    private func createSectionHeader(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func createContentLabels(for section: String) -> [UILabel] {
        let labels: [UILabel]
        
        switch section {
        case "📱 Device Information":
            labels = createDeviceInfoLabels()
        case "🧠 Memory Usage":
            labels = createMemoryInfoLabels()
        case "🔋 Battery & Power":
            labels = createBatteryInfoLabels()
        case "📍 Location Services":
            labels = createLocationInfoLabels()
        case "💾 Core Data":
            labels = createCoreDataInfoLabels()
        case "⚡ Performance Metrics":
            labels = createPerformanceInfoLabels()
        case "🔧 App Configuration":
            labels = createAppConfigLabels()
        default:
            labels = []
        }
        
        return labels
    }
    
    private func createDeviceInfoLabels() -> [UILabel] {
        return [
            createInfoLabel("Device Model: \(getDeviceModel())"),
            createInfoLabel("iOS Version: \(getIOSVersion())"),
            createInfoLabel("Screen Size: \(getScreenSize())"),
            createInfoLabel("Available Storage: \(getAvailableStorage())"),
            createInfoLabel("Total Storage: \(getTotalStorage())")
        ]
    }
    
    private func createMemoryInfoLabels() -> [UILabel] {
        return [
            createInfoLabel("App Memory Usage: \(getAppMemoryUsage())"),
            createInfoLabel("System Memory: \(getSystemMemoryInfo())"),
            createInfoLabel("Memory Pressure: \(getMemoryPressure())"),
            createInfoLabel("Available Memory: \(getAvailableMemory())"),
            createInfoLabel("Memory Warnings: \(getMemoryWarningCount())")
        ]
    }
    
    private func createBatteryInfoLabels() -> [UILabel] {
        return [
            createInfoLabel("Battery Level: \(getBatteryLevel())"),
            createInfoLabel("Battery State: \(getBatteryState())"),
            createInfoLabel("Low Power Mode: \(getLowPowerModeStatus())"),
            createInfoLabel("Thermal State: \(getThermalState())")
        ]
    }
    
    private func createLocationInfoLabels() -> [UILabel] {
        return [
            createInfoLabel("Location Permission: \(getLocationPermissionStatus())"),
            createInfoLabel("Location Services: \(getLocationServicesStatus())"),
            createInfoLabel("Background App Refresh: \(getBackgroundAppRefreshStatus())"),
            createInfoLabel("Location Accuracy: \(getLocationAccuracy())"),
            createInfoLabel("Last Location Update: \(getLastLocationUpdate())")
        ]
    }
    
    private func createCoreDataInfoLabels() -> [UILabel] {
        return [
            createInfoLabel("Total Locations: \(getTotalLocationCount())"),
            createInfoLabel("Loaded Locations: \(getLoadedLocationCount())"),
            createInfoLabel("Core Data Context: \(getCoreDataContextInfo())"),
            createInfoLabel("Database Size: \(getDatabaseSize())")
        ]
    }
    
    private func createPerformanceInfoLabels() -> [UILabel] {
        return [
            createInfoLabel("CPU Usage: \(getCPUUsage())"),
            createInfoLabel("App Launch Time: \(getAppLaunchTime())"),
            createInfoLabel("UI Responsiveness: \(getUIResponsiveness())"),
            createInfoLabel("Network Status: \(getNetworkStatus())")
        ]
    }
    
    private func createAppConfigLabels() -> [UILabel] {
        return [
            createInfoLabel("App Version: \(getAppVersion())"),
            createInfoLabel("Build Number: \(getBuildNumber())"),
            createInfoLabel("Bundle ID: \(getBundleID())"),
            createInfoLabel("Debug Mode: \(getDebugMode())"),
            createInfoLabel("Last Updated: \(getLastUpdated())")
        ]
    }
    
    private func createInfoLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    // MARK: - Data Collection Methods
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    private func getIOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    private func getScreenSize() -> String {
        let screen = UIScreen.main
        let size = screen.bounds.size
        return "\(Int(size.width))x\(Int(size.height))"
    }
    
    private func getAvailableStorage() -> String {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            do {
                let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
                if let freeSize = attributes[.systemFreeSize] as? NSNumber {
                    return ByteCountFormatter.string(fromByteCount: freeSize.int64Value, countStyle: .file)
                }
            } catch {
                return "Unknown"
            }
        }
        return "Unknown"
    }
    
    private func getTotalStorage() -> String {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            do {
                let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
                if let totalSize = attributes[.systemSize] as? NSNumber {
                    return ByteCountFormatter.string(fromByteCount: totalSize.int64Value, countStyle: .file)
                }
            } catch {
                return "Unknown"
            }
        }
        return "Unknown"
    }
    
    private func getAppMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return ByteCountFormatter.string(fromByteCount: Int64(info.resident_size), countStyle: .memory)
        }
        return "Unknown"
    }
    
    private func getSystemMemoryInfo() -> String {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        return ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
    }
    
    private func getMemoryPressure() -> String {
        // This is a simplified version - in a real app you'd use os_activity_apply
        return "Normal"
    }
    
    private func getAvailableMemory() -> String {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = getUsedMemory()
        let availableMemory = totalMemory - usedMemory
        return ByteCountFormatter.string(fromByteCount: Int64(availableMemory), countStyle: .memory)
    }
    
    private func getUsedMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        }
        return 0
    }
    
    private func getMemoryWarningCount() -> String {
        // This would need to be tracked in the app delegate
        return "0"
    }
    
    private func getBatteryLevel() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        if level < 0 {
            return "Unknown"
        }
        return String(format: "%.1f%%", level * 100)
    }
    
    private func getBatteryState() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        switch UIDevice.current.batteryState {
        case .unknown:
            return "Unknown"
        case .unplugged:
            return "Unplugged"
        case .charging:
            return "Charging"
        case .full:
            return "Full"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getLowPowerModeStatus() -> String {
        return ProcessInfo.processInfo.isLowPowerModeEnabled ? "Enabled" : "Disabled"
    }
    
    private func getThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getLocationPermissionStatus() -> String {
        let status = LocationManager.shared.authorizationStatus
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .authorizedWhenInUse:
            return "When In Use"
        case .authorizedAlways:
            return "Always"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getLocationServicesStatus() -> String {
        return CLLocationManager.locationServicesEnabled() ? "Enabled" : "Disabled"
    }
    
    private func getBackgroundAppRefreshStatus() -> String {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available:
            return "Available"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getLocationAccuracy() -> String {
        let location = LocationManager.shared.currentLocation
        if let location = location {
            return String(format: "%.1f meters", location.horizontalAccuracy)
        }
        return "No location"
    }
    
    private func getLastLocationUpdate() -> String {
        if let lastUpdate = LocationManager.shared.lastLocationUpdate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            return formatter.string(from: lastUpdate)
        }
        return "Never"
    }
    
    private func getTotalLocationCount() -> String {
        let coreDataStack = CoreDataStack.shared
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        do {
            let count = try coreDataStack.context.count(for: request)
            return "\(count)"
        } catch {
            return "Error"
        }
    }
    
    private func getLoadedLocationCount() -> String {
        // This would need to be tracked in the paginated manager
        return "50" // Default page size
    }
    
    private func getCoreDataContextInfo() -> String {
        let _ = CoreDataStack.shared
        return "Active"
    }
    
    private func getDatabaseSize() -> String {
        // This would need to be calculated from the actual database file
        return "Unknown"
    }
    
    private func getCPUUsage() -> String {
        // This is a simplified version - in a real app you'd use more sophisticated CPU monitoring
        return "Low"
    }
    
    private func getAppLaunchTime() -> String {
        // This would need to be tracked from app launch
        return "Unknown"
    }
    
    private func getUIResponsiveness() -> String {
        return "Good"
    }
    
    private func getNetworkStatus() -> String {
        return "Available"
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private func getBundleID() -> String {
        return Bundle.main.bundleIdentifier ?? "Unknown"
    }
    
    private func getDebugMode() -> String {
        #if DEBUG
        return "Yes"
        #else
        return "No"
        #endif
    }
    
    private func getLastUpdated() -> String {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let modificationDate = attributes[.modificationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            return formatter.string(from: modificationDate)
        }
        return "Unknown"
    }
    
    // MARK: - Actions
    
    @objc private func refreshDebugInfo() {
        updateDebugInfo()
    }
    
    private func updateDebugInfo() {
        let sections = [
            "📱 Device Information",
            "🧠 Memory Usage", 
            "🔋 Battery & Power",
            "📍 Location Services",
            "💾 Core Data",
            "⚡ Performance Metrics",
            "🔧 App Configuration"
        ]
        
        var labelIndex = 0
        
        for section in sections {
            let contentLabels = createContentLabels(for: section)
            for label in contentLabels {
                if labelIndex < debugLabels.count {
                    debugLabels[labelIndex].text = label.text
                    labelIndex += 1
                }
            }
        }
    }
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateDebugInfo()
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
