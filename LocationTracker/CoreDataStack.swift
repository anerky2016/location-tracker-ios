import CoreData
import Foundation
import CoreLocation
import Security

class CoreDataStack {
    static let shared = CoreDataStack()
    
    // Encryption key management
    private let encryptionKey = "KidsFunLocationTracker2024!@#"
    private let keychainService = "com.kidsfun.locationtracker.encryption"
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "LocationTracker")
        
        // Configure encrypted SQLite store
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(encryptionKey as NSString, forKey: NSPersistentStoreFileProtectionKey)
        
        // Enable file protection
        storeDescription?.setOption(FileProtectionType.complete as NSString, forKey: NSPersistentStoreFileProtectionKey)
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("❌ Failed to load encrypted store: \(error)")
                // Fallback to unencrypted store if encryption fails
                self.setupUnencryptedStore(container: container)
            } else {
                print("✅ Encrypted SQLite store loaded successfully")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Encryption Support
    
    private func setupUnencryptedStore(container: NSPersistentContainer) {
        print("⚠️ Setting up unencrypted fallback store")
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(FileProtectionType.completeUnlessOpen as NSString, forKey: NSPersistentStoreFileProtectionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
    
    private func getEncryptionKey() -> String {
        // Try to get key from Keychain first
        if let keychainKey = getKeyFromKeychain() {
            return keychainKey
        }
        
        // Generate new key and store in Keychain
        let newKey = generateEncryptionKey()
        saveKeyToKeychain(key: newKey)
        return newKey
    }
    
    private func generateEncryptionKey() -> String {
        let keyData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return keyData.base64EncodedString()
    }
    
    private func saveKeyToKeychain(key: String) {
        let keyData = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "encryption_key",
            kSecValueData as String: keyData
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("✅ Encryption key saved to Keychain")
        } else {
            print("❌ Failed to save encryption key to Keychain: \(status)")
        }
    }
    
    private func getKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "encryption_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let keyData = result as? Data,
           let key = String(data: keyData, encoding: .utf8) {
            return key
        }
        
        return nil
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
        // Use current system time instead of GPS timestamp for consistency
        // GPS timestamps can differ from system time due to timezone/clock differences
        locationEntity.timestamp = Date()
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
    
    // MARK: - Encryption Status
    
    func getEncryptionStatus() -> String {
        let storeURL = persistentContainer.persistentStoreDescriptions.first?.url
        let storePath = storeURL?.path ?? "Unknown"
        
        var status = "Database Encryption Status:\n"
        status += "📁 Database Path: \(storePath)\n"
        
        // Check if encryption key exists in Keychain
        if getKeyFromKeychain() != nil {
            status += "🔐 Encryption Key: Available in Keychain\n"
        } else {
            status += "❌ Encryption Key: Not found in Keychain\n"
        }
        
        // Check file protection
        if let storeDescription = persistentContainer.persistentStoreDescriptions.first {
            if let protection = storeDescription.options[NSPersistentStoreFileProtectionKey] as? String {
                status += "🛡️ File Protection: \(protection)\n"
            }
        }
        
        return status
    }
}
