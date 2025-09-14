import Foundation
import CoreData
import CoreLocation

/// Memory-efficient paginated location manager for handling large datasets
class PaginatedLocationManager {
    
    // MARK: - Properties
    
    private let coreDataStack = CoreDataStack.shared
    private let pageSize: Int
    private var currentPage: Int = 0
    private var totalCount: Int = 0
    private var hasMoreData: Bool = true
    
    // MARK: - Initialization
    
    init(pageSize: Int = 50) {
        self.pageSize = pageSize
        self.totalCount = getTotalLocationCount()
    }
    
    // MARK: - Public Methods
    
    /// Load the next page of locations
    func loadNextPage() -> [Location] {
        guard hasMoreData else { return [] }
        
        let locations = fetchLocations(page: currentPage, pageSize: pageSize)
        currentPage += 1
        
        // Check if we've reached the end
        if locations.count < pageSize {
            hasMoreData = false
        }
        
        print("📄 Loaded page \(currentPage) with \(locations.count) locations")
        return locations
    }
    
    /// Reset pagination to start from the beginning
    func resetPagination() {
        currentPage = 0
        hasMoreData = true
        totalCount = getTotalLocationCount()
        print("🔄 Pagination reset - total locations: \(totalCount)")
    }
    
    /// Check if there are more pages to load
    var hasMorePages: Bool {
        return hasMoreData
    }
    
    /// Get the current page number (0-based)
    var currentPageNumber: Int {
        return currentPage
    }
    
    /// Get the total number of locations
    var totalLocationCount: Int {
        return totalCount
    }
    
    /// Get the number of locations loaded so far
    var loadedLocationCount: Int {
        return currentPage * pageSize
    }
    
    // MARK: - Private Methods
    
    private func fetchLocations(page: Int, pageSize: Int) -> [Location] {
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = pageSize
        request.fetchOffset = page * pageSize
        
        // Memory optimization: Use faulting to reduce memory usage
        request.returnsObjectsAsFaults = true
        request.includesPropertyValues = true // We need property values for display
        
        do {
            return try coreDataStack.context.fetch(request)
        } catch {
            print("❌ Error fetching locations: \(error)")
            return []
        }
    }
    
    private func getTotalLocationCount() -> Int {
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        
        do {
            return try coreDataStack.context.count(for: request)
        } catch {
            print("❌ Error counting locations: \(error)")
            return 0
        }
    }
}

// MARK: - Memory Optimization Extensions

extension PaginatedLocationManager {
    
    /// Get a specific location by index (for Time Machine)
    func getLocation(at index: Int) -> Location? {
        let _ = index / pageSize
        let _ = index % pageSize
        
        // If we need a different page, we'll need to fetch it
        // For now, this is a simplified implementation
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 1
        request.fetchOffset = index
        
        do {
            let locations = try coreDataStack.context.fetch(request)
            return locations.first
        } catch {
            print("❌ Error fetching location at index \(index): \(error)")
            return nil
        }
    }
    
    /// Get locations in a specific date range (for filtering)
    func getLocationsInDateRange(from startDate: Date, to endDate: Date) -> [Location] {
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startDate as NSDate, endDate as NSDate)
        
        // Memory optimization: Limit results to prevent memory issues
        request.fetchLimit = 500
        
        do {
            return try coreDataStack.context.fetch(request)
        } catch {
            print("❌ Error fetching locations in date range: \(error)")
            return []
        }
    }
    
    /// Clear loaded data from memory (for memory management)
    func clearMemoryCache() {
        // Force Core Data to release faulted objects
        coreDataStack.context.reset()
        print("🧹 Memory cache cleared")
    }
}
