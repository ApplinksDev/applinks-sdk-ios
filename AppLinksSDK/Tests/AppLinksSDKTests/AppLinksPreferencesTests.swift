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
}
