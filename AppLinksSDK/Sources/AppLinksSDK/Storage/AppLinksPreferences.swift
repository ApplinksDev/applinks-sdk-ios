import Foundation

/// UserDefaults wrapper for AppLinks SDK
internal class AppLinksPreferences {
    private let suiteName = "com.applinks.sdk"
    private let defaults: UserDefaults
    
    // Keys
    private let keySessionId = "session_id"
    private let keyFirstLaunchCompleted = "first_launch_completed"
    private let keyVisitIds = "visit_ids"
    
    // Limits
    private let maxVisitIds = 500
    
    init() {
        self.defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }
    
    // MARK: - Session ID
    
    var sessionId: String? {
        get { defaults.string(forKey: keySessionId) }
        set { defaults.set(newValue, forKey: keySessionId) }
    }
    
    // MARK: - First Launch
    
    var isFirstLaunchCompleted: Bool {
        get { defaults.bool(forKey: keyFirstLaunchCompleted) }
        set { defaults.set(newValue, forKey: keyFirstLaunchCompleted) }
    }
    
    var isFirstLaunch: Bool {
        !isFirstLaunchCompleted
    }
    
    func markFirstLaunchCompleted() {
        isFirstLaunchCompleted = true
    }
    
    // MARK: - Visit ID Management
    
    private var visitIds: [String] {
        get { defaults.stringArray(forKey: keyVisitIds) ?? [] }
        set { defaults.set(newValue, forKey: keyVisitIds) }
    }
    
    func addVisitId(_ visitId: String) {
        var currentIds = visitIds
        
        // Check if already exists
        guard !currentIds.contains(visitId) else { return }
        
        currentIds.append(visitId)
        
        // Remove oldest entries if we exceed the limit
        if currentIds.count > maxVisitIds {
            let toRemove = currentIds.count - maxVisitIds
            currentIds.removeFirst(toRemove)
        }
        
        visitIds = currentIds
    }
    
    func hasVisitId(_ visitId: String) -> Bool {
        visitIds.contains(visitId)
    }
    
    var visitIdCount: Int {
        visitIds.count
    }
    
    func clearVisitIds() {
        defaults.removeObject(forKey: keyVisitIds)
    }
    
    // MARK: - Clear All
    
    func clear() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}