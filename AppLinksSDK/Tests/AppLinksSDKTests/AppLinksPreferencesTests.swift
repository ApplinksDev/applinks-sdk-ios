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
    
    // MARK: - Session ID Tests
    
    func testSessionIdInitiallyNil() {
        XCTAssertNil(preferences.sessionId)
    }
    
    func testSetAndGetSessionId() {
        let testSessionId = "test-session-123"
        preferences.sessionId = testSessionId
        XCTAssertEqual(preferences.sessionId, testSessionId)
    }
    
    func testSessionIdPersistence() {
        let testSessionId = "persistent-session-456"
        preferences.sessionId = testSessionId
        
        // Create new instance to test persistence
        let newPreferences = AppLinksPreferences()
        XCTAssertEqual(newPreferences.sessionId, testSessionId)
        
        // Clean up
        newPreferences.clear()
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
    
    // MARK: - Visit ID Management Tests
    
    func testVisitIdCountInitiallyZero() {
        XCTAssertEqual(preferences.visitIdCount, 0)
    }
    
    func testAddVisitId() {
        let visitId = "test-visit-123"
        preferences.addVisitId(visitId)
        
        XCTAssertEqual(preferences.visitIdCount, 1)
        XCTAssertTrue(preferences.hasVisitId(visitId))
    }
    
    func testAddMultipleVisitIds() {
        let visitIds = ["visit-1", "visit-2", "visit-3"]
        
        for visitId in visitIds {
            preferences.addVisitId(visitId)
        }
        
        XCTAssertEqual(preferences.visitIdCount, 3)
        
        for visitId in visitIds {
            XCTAssertTrue(preferences.hasVisitId(visitId))
        }
    }
    
    func testAddDuplicateVisitId() {
        let visitId = "duplicate-visit"
        
        preferences.addVisitId(visitId)
        preferences.addVisitId(visitId) // Add same ID again
        
        XCTAssertEqual(preferences.visitIdCount, 1) // Should still be 1
        XCTAssertTrue(preferences.hasVisitId(visitId))
    }
    
    func testHasVisitIdReturnsFalseForUnknownId() {
        XCTAssertFalse(preferences.hasVisitId("unknown-visit-id"))
    }
    
    func testVisitIdLimit() {
        // Add more than the limit (500) to test overflow behavior
        for i in 0..<600 {
            preferences.addVisitId("visit-\(i)")
        }
        
        XCTAssertEqual(preferences.visitIdCount, 500) // Should be capped at 500
        
        // The oldest entries should be removed
        XCTAssertFalse(preferences.hasVisitId("visit-0")) // First entry should be gone
        XCTAssertFalse(preferences.hasVisitId("visit-99")) // Early entries should be gone
        XCTAssertTrue(preferences.hasVisitId("visit-599")) // Latest entry should exist
    }
    
    func testClearVisitIds() {
        let visitIds = ["visit-1", "visit-2", "visit-3"]
        
        for visitId in visitIds {
            preferences.addVisitId(visitId)
        }
        
        XCTAssertEqual(preferences.visitIdCount, 3)
        
        preferences.clearVisitIds()
        
        XCTAssertEqual(preferences.visitIdCount, 0)
        
        for visitId in visitIds {
            XCTAssertFalse(preferences.hasVisitId(visitId))
        }
    }
    
    func testVisitIdPersistence() {
        let visitId = "persistent-visit"
        preferences.addVisitId(visitId)
        
        // Create new instance to test persistence
        let newPreferences = AppLinksPreferences()
        XCTAssertTrue(newPreferences.hasVisitId(visitId))
        XCTAssertEqual(newPreferences.visitIdCount, 1)
        
        // Clean up
        newPreferences.clear()
    }
    
    // MARK: - Clear All Tests
    
    func testClearAll() {
        // Set up some data
        preferences.sessionId = "test-session"
        preferences.markFirstLaunchCompleted()
        preferences.addVisitId("test-visit")
        
        // Verify data is set
        XCTAssertNotNil(preferences.sessionId)
        XCTAssertTrue(preferences.isFirstLaunchCompleted)
        XCTAssertEqual(preferences.visitIdCount, 1)
        
        // Clear all data
        preferences.clear()
        
        // Verify data is cleared
        XCTAssertNil(preferences.sessionId)
        XCTAssertFalse(preferences.isFirstLaunchCompleted)
        XCTAssertTrue(preferences.isFirstLaunch)
        XCTAssertEqual(preferences.visitIdCount, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testAddEmptyVisitId() {
        preferences.addVisitId("")
        XCTAssertEqual(preferences.visitIdCount, 1)
        XCTAssertTrue(preferences.hasVisitId(""))
    }
    
    func testAddVeryLongVisitId() {
        let longVisitId = String(repeating: "a", count: 1000)
        preferences.addVisitId(longVisitId)
        XCTAssertEqual(preferences.visitIdCount, 1)
        XCTAssertTrue(preferences.hasVisitId(longVisitId))
    }
    
    func testSpecialCharactersInVisitId() {
        let specialVisitId = "visit-!@#$%^&*()_+-=[]{}|;:,.<>?"
        preferences.addVisitId(specialVisitId)
        XCTAssertEqual(preferences.visitIdCount, 1)
        XCTAssertTrue(preferences.hasVisitId(specialVisitId))
    }
    
    func testUnicodeCharactersInVisitId() {
        let unicodeVisitId = "visit-🚀🌟💫"
        preferences.addVisitId(unicodeVisitId)
        XCTAssertEqual(preferences.visitIdCount, 1)
        XCTAssertTrue(preferences.hasVisitId(unicodeVisitId))
    }
    
    // MARK: - Performance Tests
    
    func testAddManyVisitIdsPerformance() {
        measure {
            for i in 0..<1000 {
                preferences.addVisitId("perf-visit-\(i)")
            }
        }
    }
    
    func testHasVisitIdPerformance() {
        // Set up data
        for i in 0..<500 {
            preferences.addVisitId("perf-visit-\(i)")
        }
        
        measure {
            for i in 0..<500 {
                _ = preferences.hasVisitId("perf-visit-\(i)")
            }
        }
    }
}