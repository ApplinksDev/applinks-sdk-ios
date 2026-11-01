import XCTest
@testable import AppLinksSDK

final class AppLinksPreferencesTests: XCTestCase {
    
    // MARK: - Properties
    
    private var preferences: AppLinksPreferences!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        preferences = AppLinksPreferences()
        // Clear any existing data
        preferences.clear()
    }
    
    override func tearDown() {
        preferences?.clear()
        preferences = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(preferences)
    }
    
    // MARK: - First Launch Tests
    
    func testIsFirstLaunchInitiallyTrue() {
        XCTAssertTrue(preferences.isFirstLaunch)
        XCTAssertFalse(preferences.isFirstLaunchCompleted)
    }
    
    func testMarkFirstLaunchCompleted() {
        preferences.markFirstLaunchCompleted()
        XCTAssertTrue(preferences.isFirstLaunchCompleted)
        XCTAssertFalse(preferences.isFirstLaunch)
    }
    
    func testFirstLaunchCompletedPersistence() {
        preferences.markFirstLaunchCompleted()
        
        // Create new instance to test persistence
        let newPreferences = AppLinksPreferences()
        XCTAssertTrue(newPreferences.isFirstLaunchCompleted)
        XCTAssertFalse(newPreferences.isFirstLaunch)
        
        // Clean up
        newPreferences.clear()
    }
    
    func testSetIsFirstLaunchCompleted() {
        preferences.isFirstLaunchCompleted = true
        XCTAssertTrue(preferences.isFirstLaunchCompleted)
        XCTAssertFalse(preferences.isFirstLaunch)
        
        preferences.isFirstLaunchCompleted = false
        XCTAssertFalse(preferences.isFirstLaunchCompleted)
        XCTAssertTrue(preferences.isFirstLaunch)
    }

    // MARK: - Consent
    
    func testSetConsent() {
        preferences.setConsent(adsConsent: true, limitedDataUse: true)
        XCTAssertTrue(preferences.consent.adsConsent)
        XCTAssertTrue(preferences.consent.limitedDataUse)
        
        preferences.setConsent(adsConsent: true, limitedDataUse: false)
        XCTAssertTrue(preferences.adsConsent)
        XCTAssertFalse(preferences.limitedDataUse)
    }
    
    func testConsentIsReadAsSetTogether() {
        let preferences = self.preferences!
        preferences.setConsent(adsConsent: false, limitedDataUse: false)
        
        let lock = NSLock()
        var mixed = 0
        DispatchQueue.concurrentPerform(iterations: 2) { index in
            for step in 0..<500 {
                if index == 0 {
                    let value = step % 2 == 0
                    preferences.setConsent(adsConsent: value, limitedDataUse: value)
                } else {
                    let consent = preferences.consent
                    if consent.adsConsent != consent.limitedDataUse {
                        lock.lock()
                        mixed += 1
                        lock.unlock()
                    }
                }
            }
        }
        
        XCTAssertEqual(mixed, 0)
    }
}
