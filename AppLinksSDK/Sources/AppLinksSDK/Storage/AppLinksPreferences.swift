import Foundation

/// UserDefaults wrapper for AppLinks SDK
internal class AppLinksPreferences: @unchecked Sendable {
    private let suiteName: String
    private let defaults: UserDefaults
    /// Makes the consent's two flags one value
    private let consentLock = NSLock()
    
    // Keys
    private let keyFirstLaunchCompleted = "first_launch_completed"
    private let keyInstallReportDue = "install_report_due"
    private let keyInstallLookupCompleted = "install_lookup_completed"
    private let keyPendingClickId = "pending_click_id"
    private let keyInstallReportSent = "install_report_sent"
    private let keyAttributionId = "attribution_id"
    private let keyAdsConsent = "ads_consent"
    private let keyLimitedDataUse = "limited_data_use"
    private let keyAdvertisingId = "advertising_id"
    private let keySentAttributionFields = "sent_attribution_fields"
        
    init(suiteName: String = "com.applinks.sdk") {
        self.suiteName = suiteName
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
    
    // MARK: - Install Attribution
    
    /// Whether this install still has to be reported. Set when the SDK
    /// initialises on a fresh install, cleared once the server answered.
    var installReportDue: Bool {
        get { defaults.bool(forKey: keyInstallReportDue) }
        set { defaults.set(newValue, forKey: keyInstallReportDue) }
    }
    
    /// Whether the deferred deep link lookup the install report waits for ran
    var installLookupCompleted: Bool {
        get { defaults.bool(forKey: keyInstallLookupCompleted) }
        set { defaults.set(newValue, forKey: keyInstallLookupCompleted) }
    }
    
    /// The click ID found by the lookup, kept until the install is reported
    /// (the clipboard was cleared)
    var pendingClickId: String? {
        get { defaults.string(forKey: keyPendingClickId) }
        set { defaults.set(newValue, forKey: keyPendingClickId) }
    }
    
    /// Whether the install report was sent before without an answer (a
    /// timeout, a lost connection): the server may have recorded it
    var installReportSent: Bool {
        get { defaults.bool(forKey: keyInstallReportSent) }
        set { defaults.set(newValue, forKey: keyInstallReportSent) }
    }
    
    /// The attribution the server recorded for this install
    var attributionId: String? {
        get { defaults.string(forKey: keyAttributionId) }
        set { defaults.set(newValue, forKey: keyAttributionId) }
    }
    
    /// The consent the app gave with updateConsent
    var adsConsent: Bool {
        get { defaults.bool(forKey: keyAdsConsent) }
        set { defaults.set(newValue, forKey: keyAdsConsent) }
    }
    
    var limitedDataUse: Bool {
        get { defaults.bool(forKey: keyLimitedDataUse) }
        set { defaults.set(newValue, forKey: keyLimitedDataUse) }
    }
    
    /// Both consent flags, read together: never the new consent with the
    /// old limited data use
    var consent: (adsConsent: Bool, limitedDataUse: Bool) {
        consentLock.lock()
        defer { consentLock.unlock() }
        return (adsConsent, limitedDataUse)
    }
    
    /// Set both consent flags in one step
    func setConsent(adsConsent: Bool, limitedDataUse: Bool) {
        consentLock.lock()
        defer { consentLock.unlock() }
        self.adsConsent = adsConsent
        self.limitedDataUse = limitedDataUse
    }
    
    /// The advertising ID the app set with setAdvertisingId
    var advertisingId: String? {
        get { defaults.string(forKey: keyAdvertisingId) }
        set { defaults.set(newValue, forKey: keyAdvertisingId) }
    }
    
    /// The fields the server was last sent successfully
    var sentAttributionFields: AttributionFields? {
        get {
            guard let data = defaults.data(forKey: keySentAttributionFields) else { return nil }
            return try? JSONDecoder().decode(AttributionFields.self, from: data)
        }
        set {
            defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: keySentAttributionFields)
        }
    }
    
    // MARK: - Clear All
    
    func clear() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
