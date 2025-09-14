import Foundation
import CoreData
import CoreLocation

@objc(Location)
public class Location: NSManagedObject {
    
    convenience init(context: NSManagedObjectContext, clLocation: CLLocation) {
        self.init(context: context)
        self.latitude = clLocation.coordinate.latitude
        self.longitude = clLocation.coordinate.longitude
        self.altitude = clLocation.altitude
        self.horizontalAccuracy = clLocation.horizontalAccuracy
        self.verticalAccuracy = clLocation.verticalAccuracy
        self.course = clLocation.course
        self.courseAccuracy = clLocation.courseAccuracy
        self.speed = clLocation.speed
        self.speedAccuracy = clLocation.speedAccuracy
        self.timestamp = clLocation.timestamp
        self.accuracy = clLocation.horizontalAccuracy
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var clLocation: CLLocation {
        return CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            courseAccuracy: courseAccuracy,
            speed: speed,
            speedAccuracy: speedAccuracy,
            timestamp: timestamp ?? Date()
        )
    }
}
