import Foundation
import CoreLocation

/// Lightweight data structure for Time Machine functionality
/// Reduces memory usage by storing only essential data instead of full Location objects
struct TimeMachineLocation {
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let index: Int
    
    // Optional additional data (only when needed)
    let altitude: Double?
    let horizontalAccuracy: Double?
    let speed: Double?
    
    // MARK: - Initialization
    
    init(coordinate: CLLocationCoordinate2D, timestamp: Date, index: Int, 
         altitude: Double? = nil, horizontalAccuracy: Double? = nil, speed: Double? = nil) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.index = index
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
    }
    
    // MARK: - Factory Methods
    
    /// Create TimeMachineLocation from a Core Data Location object
    static func from(_ location: Location, index: Int) -> TimeMachineLocation {
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        return TimeMachineLocation(
            coordinate: coordinate,
            timestamp: location.timestamp ?? Date(),
            index: index,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed
        )
    }
    
    /// Create TimeMachineLocation from a CLLocation object
    static func from(_ clLocation: CLLocation, index: Int) -> TimeMachineLocation {
        return TimeMachineLocation(
            coordinate: clLocation.coordinate,
            timestamp: clLocation.timestamp,
            index: index,
            altitude: clLocation.altitude,
            horizontalAccuracy: clLocation.horizontalAccuracy,
            speed: clLocation.speed
        )
    }
    
    // MARK: - Computed Properties
    
    /// Get formatted timestamp string
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    /// Get coordinate string for display
    var coordinateString: String {
        return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
    
    /// Get altitude string for display (if available)
    var altitudeString: String? {
        guard let altitude = altitude else { return nil }
        return String(format: "%.1f m", altitude)
    }
    
    /// Get accuracy string for display (if available)
    var accuracyString: String? {
        guard let accuracy = horizontalAccuracy else { return nil }
        return String(format: "±%.1f m", accuracy)
    }
    
    /// Get speed string for display (if available)
    var speedString: String? {
        guard let speed = speed, speed >= 0 else { return nil }
        return String(format: "%.1f m/s", speed)
    }
}

// MARK: - Equatable

extension TimeMachineLocation: Equatable {
    static func == (lhs: TimeMachineLocation, rhs: TimeMachineLocation) -> Bool {
        return lhs.index == rhs.index && 
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.timestamp == rhs.timestamp
    }
}

// MARK: - Comparable

extension TimeMachineLocation: Comparable {
    static func < (lhs: TimeMachineLocation, rhs: TimeMachineLocation) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
}

// MARK: - Hashable

extension TimeMachineLocation: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(index)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(timestamp)
    }
}

// MARK: - Memory Usage Information

extension TimeMachineLocation {
    /// Estimated memory usage of this struct (in bytes)
    var estimatedMemoryUsage: Int {
        // Basic struct size + optional data
        var size = MemoryLayout<TimeMachineLocation>.size
        
        // Add size for optional properties if they exist
        if altitude != nil { size += MemoryLayout<Double>.size }
        if horizontalAccuracy != nil { size += MemoryLayout<Double>.size }
        if speed != nil { size += MemoryLayout<Double>.size }
        
        return size
    }
    
    /// Compare memory usage with full Location object
    static func memorySavings(comparedTo locationCount: Int) -> String {
        let timeMachineSize = MemoryLayout<TimeMachineLocation>.size * locationCount
        let fullLocationSize = 400 * locationCount // Approximate size of full Location object
        
        let savings = fullLocationSize - timeMachineSize
        let percentage = Double(savings) / Double(fullLocationSize) * 100
        
        return String(format: "Memory savings: %d bytes (%.1f%%)", savings, percentage)
    }
}
