import Foundation

/// UserDefaults wrapper for AppLinks SDK
internal class AppLinksPreferences {
    private let suiteName = "com.applinks.sdk"
    private let defaults: UserDefaults
    
    // Keys
    private let keyFirstLaunchCompleted = "first_launch_completed"
        
    init() {
        self.defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
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
    
    // MARK: - Clear All
    
    func clear() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
