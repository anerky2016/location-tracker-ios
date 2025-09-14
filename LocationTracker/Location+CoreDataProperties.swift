import Foundation
import CoreData

extension Location {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Location> {
        return NSFetchRequest<Location>(entityName: "Location")
    }

    @NSManaged public var accuracy: Double
    @NSManaged public var altitude: Double
    @NSManaged public var course: Double
    @NSManaged public var courseAccuracy: Double
    @NSManaged public var horizontalAccuracy: Double
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var speed: Double
    @NSManaged public var speedAccuracy: Double
    @NSManaged public var timestamp: Date?
    @NSManaged public var verticalAccuracy: Double

}

extension Location : Identifiable {

}
