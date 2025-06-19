import Foundation
import SwiftData

@Model
class SyncedSettings {
    var id: UUID = UUID()
    var isBiometricAuthEnabled: Bool = false
    var createdDate: Date = Date()
    
    init(isBiometricAuthEnabled: Bool = false) {
        self.isBiometricAuthEnabled = isBiometricAuthEnabled
    }
    
    static func getOrCreate(in context: ModelContext) -> SyncedSettings {
        let descriptor = FetchDescriptor<SyncedSettings>()
        
        do {
            let existingSettings = try context.fetch(descriptor)
            if let settings = existingSettings.first {
                return settings
            }
        } catch {
            print("❌ Error fetching SyncedSettings: \(error)")
        }
        
        // Create new settings if none exist
        let newSettings = SyncedSettings()
        context.insert(newSettings)
        
        do {
            try context.save()
        } catch {
            print("❌ Error saving new SyncedSettings: \(error)")
        }
        
        return newSettings
    }
}