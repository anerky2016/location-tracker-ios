import CoreData
import Foundation
import CoreLocation

class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "LocationTracker")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func saveLocation(_ location: CLLocation) {
        let context = persistentContainer.viewContext
        let locationEntity = Location(context: context)
        
        locationEntity.latitude = location.coordinate.latitude
        locationEntity.longitude = location.coordinate.longitude
        locationEntity.altitude = location.altitude
        locationEntity.horizontalAccuracy = location.horizontalAccuracy
        locationEntity.verticalAccuracy = location.verticalAccuracy
        locationEntity.course = location.course
        locationEntity.courseAccuracy = location.courseAccuracy
        locationEntity.speed = location.speed
        locationEntity.speedAccuracy = location.speedAccuracy
        locationEntity.timestamp = location.timestamp
        locationEntity.accuracy = location.horizontalAccuracy
        
        saveContext()
    }
    
    func fetchLocations(limit: Int = 1000) -> [Location] {
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching locations: \(error)")
            return []
        }
    }
    
    func deleteOldLocations(olderThan days: Int = 30) {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
        
        do {
            let oldLocations = try context.fetch(request)
            for location in oldLocations {
                context.delete(location)
            }
            saveContext()
            print("Deleted \(oldLocations.count) old location records")
        } catch {
            print("Error deleting old locations: \(error)")
        }
    }
}
