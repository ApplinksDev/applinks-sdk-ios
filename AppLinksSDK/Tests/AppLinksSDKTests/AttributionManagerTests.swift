import XCTest
@testable import AppLinksSDK

final class AttributionManagerTests: XCTestCase {
    private typealias Stub = MockURLProtocol.Stub

    private var host: String!
    private var suiteName: String!
    private var preferences: AppLinksPreferences!
    private var deviceInfo: MockAttributionDeviceInfo!
    private var manager: AttributionManager!

    private let clickId = AttributionFixtures.clickId
    private let attributionId = AttributionFixtures.attributionId

    override func setUp() {
        super.setUp()
        host = "\(UUID().uuidString.lowercased()).applinks.test"
        suiteName = "com.applinks.sdk.tests.\(UUID().uuidString)"
        preferences = AppLinksPreferences(suiteName: suiteName)
        deviceInfo = MockAttributionDeviceInfo()
        manager = makeManager()
    }

    override func tearDown() {
        preferences.clear()
        MockURLProtocol.reset(host: host)
        manager = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// A manager as the SDK makes one at initialisation; a new one is a restart
    private func makeManager(apiKey: String = "pk_test_123") -> AttributionManager {
        let apiClient = AppLinksApiClient(serverUrl: "https://\(host!)", apiKey: apiKey, session: MockURLProtocol.session())
        return AttributionManager(apiClient: apiClient, preferences: preferences, deviceInfo: deviceInfo)
    }

    private var requests: [MockURLProtocol.RecordedRequest] {
        MockURLProtocol.requests(host: host)
    }

    private func respond(_ responder: @escaping (MockURLProtocol.RecordedRequest) -> Stub) {
        MockURLProtocol.respond(host: host, responder)
    }

    /// The server records installs and updates
    private func respondSuccessfully(delay: TimeInterval = 0) {
        respond { request in
            Stub(status: request.method == "POST" ? 201 : 200, body: AttributionFixtures.attributionResponse(), delay: delay)
        }
    }

    /// A fresh install whose deferred deep link lookup ran
    private func lookupDone(clickId: String? = AttributionFixtures.clickId) {
        preferences.installReportDue = true
        preferences.installLookupCompleted = true
        preferences.pendingClickId = clickId
    }

    /// An install already reported, with the device's current fields
    private func reported() {
        preferences.attributionId = attributionId
        preferences.sentAttributionFields = AttributionFields(
            attStatus: "not_determined",
            adsConsent: false,
            limitedDataUse: false,
            advertisingId: nil,
            appVersion: "2.3.1",
            osVersion: "17.5.1"
        )
    }

    // MARK: - Install report

    func testReportsTheInstall() async {
        respondSuccessfully()
        lookupDone()

        await manager.sync()

        XCTAssertEqual(requests.count, 1)
        let request = requests[0]
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/attributions")
        XCTAssertEqual(request.headers["Authorization"], "Bearer pk_test_123")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(
            request.body,
            "{\"ads_consent\":false,\"app_version\":\"2.3.1\",\"att_status\":\"not_determined\",\"bundle_id\":\"com.example.app\","
            + "\"click_id\":\"\(clickId)\",\"limited_data_use\":false,\"os_version\":\"17.5.1\",\"platform\":\"ios\"}"
        )
        XCTAssertNil(request.json["url"])

        XCTAssertEqual(preferences.attributionId, attributionId)
        XCTAssertFalse(preferences.installReportDue)
        XCTAssertNil(preferences.pendingClickId)
    }

    func testReportsAnUnmatchedInstallWithoutClickId() async {
        respondSuccessfully()
        lookupDone(clickId: nil)

        await manager.sync()

        XCTAssertEqual(requests.count, 1)
        XCTAssertNil(requests[0].json["click_id"])
        XCTAssertNil(requests[0].json["url"])
        XCTAssertEqual(preferences.attributionId, attributionId)
    }

    func testReportsTheConsentAndAdvertisingIdSetBeforeTheReport() async {
        respondSuccessfully()
        lookupDone()
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.adsConsent = true
        preferences.limitedDataUse = true
        preferences.advertisingId = AttributionFixtures.idfa

        await manager.sync()

        XCTAssertEqual(
            requests.first?.body,
            "{\"ads_consent\":true,\"advertising_id\":\"\(AttributionFixtures.idfa)\",\"app_version\":\"2.3.1\","
            + "\"att_status\":\"authorized\",\"bundle_id\":\"com.example.app\",\"click_id\":\"\(clickId)\","
            + "\"limited_data_use\":true,\"os_version\":\"17.5.1\",\"platform\":\"ios\"}"
        )
    }

    func testLeavesOutTheFieldsThatCantBeRead() async {
        respondSuccessfully()
        lookupDone(clickId: nil)
        deviceInfo.trackingAuthorizationStatus = nil
        deviceInfo.appVersion = nil
        deviceInfo.osVersion = nil

        await manager.sync()

        XCTAssertEqual(
            requests.first?.body,
            "{\"ads_consent\":false,\"bundle_id\":\"com.example.app\",\"limited_data_use\":false,\"platform\":\"ios\"}"
        )
    }

    func testAlreadyReportedIsASuccess() async {
        respond { _ in Stub(status: 200, body: AttributionFixtures.attributionResponse(matched: true)) }
        lookupDone()

        await manager.sync()

        XCTAssertEqual(preferences.attributionId, attributionId)
        XCTAssertFalse(preferences.installReportDue)
        XCTAssertFalse(preferences.installReportSent)
        // Reported first by another device the click ID reached: its stricter
        // choice isn't overridden
        XCTAssertEqual(requests.map(\.method), ["POST"])
        XCTAssertEqual(preferences.sentAttributionFields?.adsConsent, false)
    }

    func testARetriedReportAnsweredAsAlreadyReportedSendsWhatTheUserAllowedSince() async {
        // The first report reached the server, but its answer was lost
        respond { _ in Stub(error: URLError(.timedOut)) }
        lookupDone()
        await manager.sync()
        XCTAssertTrue(preferences.installReportSent)

        // Before the next launch, the user allowed tracking and ad measurement
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.adsConsent = true
        preferences.advertisingId = AttributionFixtures.idfa

        // The retry gets the install recorded first, with only its stricter values
        respond { _ in Stub(status: 200, body: AttributionFixtures.attributionResponse(matched: true)) }
        manager = makeManager()
        await manager.sync()

        XCTAssertEqual(requests.map(\.method), ["POST", "POST", "PATCH"])
        XCTAssertEqual(requests[1].json["ads_consent"] as? Bool, true)
        XCTAssertEqual(requests[2].path, "/api/v1/attributions/\(attributionId)")
        XCTAssertEqual(
            requests[2].body,
            "{\"ads_consent\":true,\"advertising_id\":\"\(AttributionFixtures.idfa)\",\"app_version\":\"2.3.1\","
            + "\"att_status\":\"authorized\",\"limited_data_use\":false,\"os_version\":\"17.5.1\"}"
        )
        XCTAssertEqual(preferences.attributionId, attributionId)
        XCTAssertFalse(preferences.installReportSent)

        // Then only changes
        await manager.sync()
        XCTAssertEqual(requests.count, 3)
    }

    func testARetriedReportAnsweredAsAlreadyReportedRemovesTheFirstReportsAdvertisingId() async {
        respond { _ in Stub(status: 503) }
        lookupDone()
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.adsConsent = true
        preferences.advertisingId = AttributionFixtures.idfa
        await manager.sync()

        // The app removed the ID before the retry
        preferences.advertisingId = nil
        respond { _ in Stub(status: 200, body: AttributionFixtures.attributionResponse()) }
        manager = makeManager()
        await manager.sync()

        XCTAssertEqual(requests.map(\.method), ["POST", "POST", "PATCH"])
        XCTAssertEqual(
            requests[2].body,
            "{\"ads_consent\":true,\"advertising_id\":null,\"app_version\":\"2.3.1\","
            + "\"att_status\":\"authorized\",\"limited_data_use\":false,\"os_version\":\"17.5.1\"}"
        )
    }

    func testARetriedReportAnsweredAsAlreadyReportedKeepsTheStricterValues() async {
        respond { _ in Stub(error: URLError(.networkConnectionLost)) }
        lookupDone()
        preferences.limitedDataUse = true
        await manager.sync()

        respond { _ in Stub(status: 200, body: AttributionFixtures.attributionResponse()) }
        manager = makeManager()
        await manager.sync()

        // No consent and limited data use: what the repeat applied, not sent again
        XCTAssertEqual(requests.map(\.method), ["POST", "POST", "PATCH"])
        XCTAssertEqual(
            requests[2].body,
            "{\"advertising_id\":null,\"app_version\":\"2.3.1\",\"att_status\":\"not_determined\",\"os_version\":\"17.5.1\"}"
        )
    }

    func testWaitsForTheLookup() async throws {
        respondSuccessfully()
        preferences.installReportDue = true

        await manager.sync()

        XCTAssertTrue(requests.isEmpty)
        XCTAssertTrue(preferences.installReportDue)
    }

    func testDoesNotReportAnInstallThatIsNotDue() async {
        // An app upgraded from an older SDK: first launch was completed, no report is due
        respondSuccessfully()
        preferences.installLookupCompleted = true

        await manager.sync()
        preferences.adsConsent = true
        await manager.sync()

        XCTAssertTrue(requests.isEmpty)
    }

    func testRecordInstallLookupKeepsOnlyTheClickId() async throws {
        respondSuccessfully()
        preferences.installReportDue = true

        manager.recordInstallLookup(url: URL(string: "https://go.acme.test/promo?ref=ad&ck=\(clickId.uppercased())"))

        XCTAssertEqual(preferences.pendingClickId, clickId)
        XCTAssertTrue(preferences.installLookupCompleted)
        try await waitUntil { self.preferences.attributionId != nil }
        XCTAssertEqual(requests.first?.json["click_id"] as? String, clickId)
        XCTAssertFalse(requests.first?.body.contains("go.acme.test") ?? true)
    }

    func testOnlyTheFirstLookupCounts() async throws {
        preferences.installReportDue = true

        manager.recordInstallLookup(url: nil)
        manager.recordInstallLookup(url: URL(string: "https://go.acme.test/promo?ck=\(clickId)"))

        XCTAssertNil(preferences.pendingClickId)
    }

    func testConcurrentLookupsRecordOnlyOne() {
        // The server never answers, so nothing else writes the preferences
        respond { _ in Stub(status: 503) }
        let manager = self.manager!
        let preferences = self.preferences!
        let url = URL(string: "https://go.acme.test/promo?ck=\(clickId)")
        for _ in 0..<200 {
            preferences.installReportDue = true
            preferences.installLookupCompleted = false
            preferences.pendingClickId = nil

            // Whether each recorded lookup had found the click ID
            let lock = NSLock()
            var recorded: [Bool] = []
            DispatchQueue.concurrentPerform(iterations: 4) { index in
                let lookupUrl = index == 0 ? url : nil
                if manager.recordInstallLookup(url: lookupUrl) {
                    lock.lock()
                    recorded.append(lookupUrl != nil)
                    lock.unlock()
                }
            }

            XCTAssertEqual(recorded.count, 1)
            // The click ID kept is the recorded lookup's: a later nil never replaces it
            XCTAssertEqual(preferences.pendingClickId, recorded.first == true ? clickId : nil)
        }
    }

    func testRecordInstallLookupDoesNothingWhenNoReportIsDue() {
        manager.recordInstallLookup(url: URL(string: "https://go.acme.test/promo?ck=\(clickId)"))

        XCTAssertNil(preferences.pendingClickId)
        XCTAssertFalse(preferences.installLookupCompleted)
    }

    // MARK: - Install report failures

    func testRetriesAtTheNextInitialisation() async {
        for stub in [
            Stub(error: URLError(.notConnectedToInternet)),
            Stub(error: URLError(.timedOut)),
            Stub(status: 500),
            Stub(status: 503, body: AttributionFixtures.errorResponse(status: 503, message: "Unavailable")),
            Stub(status: 408),
            Stub(status: 429),
            Stub(status: 201, body: "<html>")
        ] {
            MockURLProtocol.reset(host: host)
            preferences.clear()
            manager = makeManager()
            respond { _ in stub }
            lookupDone()

            await manager.sync()

            XCTAssertEqual(requests.count, 1, "\(stub)")
            XCTAssertNil(preferences.attributionId, "\(stub)")
            XCTAssertTrue(preferences.installReportDue, "\(stub)")
            XCTAssertEqual(preferences.pendingClickId, clickId, "\(stub)")

            // Not retried before the next initialisation
            preferences.adsConsent = true
            await manager.sync()
            XCTAssertEqual(requests.count, 1, "\(stub)")
            preferences.adsConsent = false

            // The next initialisation (a restart) retries it, with the kept click ID
            respondSuccessfully()
            manager = makeManager()
            await manager.sync()

            XCTAssertEqual(requests.count, 2, "\(stub)")
            XCTAssertEqual(requests[1].method, "POST", "\(stub)")
            XCTAssertEqual(requests[1].json["click_id"] as? String, clickId, "\(stub)")
            XCTAssertEqual(preferences.attributionId, attributionId, "\(stub)")
            XCTAssertFalse(preferences.installReportDue, "\(stub)")
        }
    }

    func testStopsOnOtherClientErrors() async {
        for (status, message) in [
            (400, "bundle_id parameter is required"),
            (401, "Invalid or missing API token"),
            (403, "Forbidden"),
            (404, "App not found"),
            (422, "Validation failed")
        ] {
            MockURLProtocol.reset(host: host)
            preferences.clear()
            manager = makeManager()
            respond { _ in Stub(status: status, body: AttributionFixtures.errorResponse(status: status, message: message)) }
            lookupDone()

            await manager.sync()

            XCTAssertEqual(requests.count, 1, "\(status)")
            XCTAssertNil(preferences.attributionId, "\(status)")
            XCTAssertFalse(preferences.installReportDue, "\(status)")
            XCTAssertNil(preferences.pendingClickId, "\(status)")

            // Not retried, even after a restart
            manager = makeManager()
            await manager.sync()
            XCTAssertEqual(requests.count, 1, "\(status)")
        }
    }

    func testRejectionCauses() {
        XCTAssertTrue(
            AttributionManager.rejectionCause(statusCode: 404, message: "App not found", bundleId: "com.example.app")
                .contains("no Applinks project has the iOS bundle ID \"com.example.app\"")
        )
        XCTAssertTrue(
            AttributionManager.rejectionCause(statusCode: 401, message: "Invalid or missing API token", bundleId: nil)
                .contains("API key was refused")
        )
        XCTAssertEqual(
            AttributionManager.rejectionCause(statusCode: 422, message: "Validation failed", bundleId: nil),
            "the server answered 422 (Validation failed)."
        )
    }

    // MARK: - Serialization

    func testConcurrentSyncsReportTheInstallOnce() async {
        respondSuccessfully(delay: 0.2)
        lookupDone()
        let manager = self.manager!

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { await manager.sync() }
            }
        }

        XCTAssertEqual(requests.filter { $0.method == "POST" }.count, 1)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(preferences.attributionId, attributionId)
    }

    func testConcurrentTriggersReportTheInstallOnce() async throws {
        respondSuccessfully(delay: 0.2)
        lookupDone()

        for _ in 0..<10 {
            manager.trigger()
        }
        try await waitUntil { self.preferences.attributionId != nil }
        try await settle()

        XCTAssertEqual(requests.count, 1)
    }

    func testAChangeMadeDuringTheReportIsSentAfterIt() async throws {
        respondSuccessfully(delay: 0.3)
        lookupDone()
        let manager = self.manager!

        let report = Task { await manager.sync() }
        try await waitUntil { self.requests.count == 1 }
        preferences.adsConsent = true
        await manager.sync()
        await report.value

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].method, "POST")
        XCTAssertEqual(requests[0].json["ads_consent"] as? Bool, false)
        XCTAssertEqual(requests[1].method, "PATCH")
        XCTAssertEqual(requests[1].path, "/api/v1/attributions/\(attributionId)")
        XCTAssertEqual(requests[1].body, "{\"ads_consent\":true}")
    }

    // MARK: - Updates

    func testSendsTheChangedConsent() async {
        respondSuccessfully()
        reported()
        preferences.adsConsent = true

        await manager.sync()

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].method, "PATCH")
        XCTAssertEqual(requests[0].path, "/api/v1/attributions/\(attributionId)")
        XCTAssertEqual(requests[0].headers["Authorization"], "Bearer pk_test_123")
        XCTAssertEqual(requests[0].body, "{\"ads_consent\":true}")
        XCTAssertEqual(preferences.sentAttributionFields?.adsConsent, true)
    }

    func testSendsNothingWhenNothingChanged() async {
        respondSuccessfully()
        reported()

        await manager.sync()
        await manager.sync()

        XCTAssertTrue(requests.isEmpty)
    }

    func testSendsOnlyTheFieldsThatChanged() async {
        respondSuccessfully()
        reported()
        preferences.limitedDataUse = true
        deviceInfo.trackingAuthorizationStatus = "denied"

        await manager.sync()
        // Already sent
        await manager.sync()

        XCTAssertEqual(requests.map(\.body), ["{\"att_status\":\"denied\",\"limited_data_use\":true}"])
    }

    func testSendsTheAdvertisingIdAndItsRemoval() async {
        respondSuccessfully()
        reported()

        preferences.advertisingId = AttributionFixtures.idfa
        await manager.sync()
        preferences.advertisingId = nil
        await manager.sync()

        XCTAssertEqual(requests.map(\.body), [
            "{\"advertising_id\":\"\(AttributionFixtures.idfa)\"}",
            "{\"advertising_id\":null}"
        ])
        XCTAssertTrue(requests[1].json["advertising_id"] is NSNull)
    }

    // The server drops the advertising ID while tracking isn't allowed (iOS:
    // ATT authorized and ads_consent true), so it's sent again once it is.

    func testSendsTheAdvertisingIdAgainWhenConsentIsGrantedAgain() async {
        respondSuccessfully()
        reported()
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.adsConsent = true
        preferences.advertisingId = AttributionFixtures.idfa
        await manager.sync()

        preferences.adsConsent = false
        await manager.sync()
        preferences.adsConsent = true
        await manager.sync()

        XCTAssertEqual(requests.map(\.body), [
            "{\"ads_consent\":true,\"advertising_id\":\"\(AttributionFixtures.idfa)\",\"att_status\":\"authorized\"}",
            "{\"ads_consent\":false}",
            "{\"ads_consent\":true,\"advertising_id\":\"\(AttributionFixtures.idfa)\"}"
        ])
    }

    func testSendsTheAdvertisingIdSetBeforeConsentOnceConsentIsGiven() async {
        respondSuccessfully()
        reported()
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.advertisingId = AttributionFixtures.idfa
        await manager.sync()

        preferences.adsConsent = true
        await manager.sync()
        // Already sent
        await manager.sync()

        XCTAssertEqual(requests.map(\.body), [
            "{\"advertising_id\":\"\(AttributionFixtures.idfa)\",\"att_status\":\"authorized\"}",
            "{\"ads_consent\":true,\"advertising_id\":\"\(AttributionFixtures.idfa)\"}"
        ])
    }

    func testSendsTheAdvertisingIdAgainWhenTrackingIsAuthorizedAgain() async {
        respondSuccessfully()
        reported()
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.adsConsent = true
        preferences.advertisingId = AttributionFixtures.idfa
        await manager.sync()

        deviceInfo.trackingAuthorizationStatus = "denied"
        await manager.sync()
        deviceInfo.trackingAuthorizationStatus = "authorized"
        await manager.sync()

        XCTAssertEqual(requests.map(\.body).suffix(2), [
            "{\"att_status\":\"denied\"}",
            "{\"advertising_id\":\"\(AttributionFixtures.idfa)\",\"att_status\":\"authorized\"}"
        ])
    }

    func testSendsTheAdvertisingIdOfTheInstallReportOnceConsentIsGiven() async {
        respondSuccessfully()
        lookupDone()
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.advertisingId = AttributionFixtures.idfa
        await manager.sync()
        XCTAssertEqual(requests.first?.json["advertising_id"] as? String, AttributionFixtures.idfa)

        preferences.adsConsent = true
        await manager.sync()

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[1].body, "{\"ads_consent\":true,\"advertising_id\":\"\(AttributionFixtures.idfa)\"}")
    }

    func testGrantingConsentWithoutAnAdvertisingIdSendsOnlyTheConsent() async {
        respondSuccessfully()
        reported()
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.adsConsent = true

        await manager.sync()

        XCTAssertEqual(requests.map(\.body), ["{\"ads_consent\":true,\"att_status\":\"authorized\"}"])
    }

    func testSendsAnAppOrOSUpdate() async {
        respondSuccessfully()
        reported()
        deviceInfo.appVersion = "2.4.0"
        deviceInfo.osVersion = "18.0"

        // At the next initialisation
        manager = makeManager()
        await manager.sync()

        XCTAssertEqual(requests.map(\.body), ["{\"app_version\":\"2.4.0\",\"os_version\":\"18.0\"}"])
        XCTAssertEqual(preferences.sentAttributionFields?.appVersion, "2.4.0")
    }

    func testDoesNotSendAVersionThatCantBeRead() async {
        respondSuccessfully()
        reported()
        deviceInfo.appVersion = nil
        deviceInfo.trackingAuthorizationStatus = nil

        await manager.sync()

        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(preferences.sentAttributionFields?.appVersion, "2.3.1")
    }

    func testRetriesAFailedUpdateAtTheNextTrigger() async {
        for stub in [Stub(error: URLError(.timedOut)), Stub(status: 502), Stub(status: 408), Stub(status: 429)] {
            MockURLProtocol.reset(host: host)
            preferences.clear()
            reported()
            respond { _ in stub }
            preferences.adsConsent = true

            await manager.sync()
            XCTAssertEqual(preferences.sentAttributionFields?.adsConsent, false, "\(stub)")

            respondSuccessfully()
            await manager.sync()

            XCTAssertEqual(requests.map(\.body), ["{\"ads_consent\":true}", "{\"ads_consent\":true}"], "\(stub)")
            XCTAssertEqual(preferences.sentAttributionFields?.adsConsent, true, "\(stub)")
        }
    }

    func testDoesNotRetryARefusedUpdate() async {
        for status in [400, 401, 404, 422] {
            MockURLProtocol.reset(host: host)
            preferences.clear()
            reported()
            respond { _ in Stub(status: status, body: AttributionFixtures.errorResponse(status: status, message: "Refused")) }
            preferences.advertisingId = "not-an-idfa"

            await manager.sync()
            await manager.sync()

            XCTAssertEqual(requests.count, 1, "\(status)")
            XCTAssertEqual(preferences.sentAttributionFields?.advertisingId, "not-an-idfa", "\(status)")
            XCTAssertEqual(preferences.attributionId, attributionId, "\(status)")
        }
    }

    func testSendsTheConsentOfAnUpdateRefusedForTheAdvertisingId() async {
        // The server refuses the whole update when the advertising ID it would store isn't an IDFA
        respond { request in
            request.json["advertising_id"] != nil
                ? Stub(status: 422, body: AttributionFixtures.errorResponse(status: 422, message: "Validation failed: Advertising id must be an IDFA or a GAID"))
                : Stub(status: 200, body: AttributionFixtures.attributionResponse())
        }
        reported()
        preferences.advertisingId = "not-an-idfa"
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.adsConsent = true

        await manager.sync()

        XCTAssertEqual(requests.map(\.body), [
            "{\"ads_consent\":true,\"advertising_id\":\"not-an-idfa\",\"att_status\":\"authorized\"}",
            "{\"ads_consent\":true,\"att_status\":\"authorized\"}"
        ])
        XCTAssertEqual(preferences.sentAttributionFields?.adsConsent, true)
        XCTAssertEqual(preferences.sentAttributionFields?.attStatus, "authorized")
    }

    func testRetriesTheConsentOfAnUpdateRefusedForTheAdvertisingIdWhenItsResendFails() async {
        respond { request in
            request.json["advertising_id"] != nil
                ? Stub(status: 422, body: AttributionFixtures.errorResponse(status: 422, message: "Validation failed"))
                : Stub(status: 503)
        }
        reported()
        preferences.advertisingId = "not-an-idfa"
        deviceInfo.trackingAuthorizationStatus = "authorized"
        preferences.adsConsent = true

        await manager.sync()
        XCTAssertEqual(preferences.sentAttributionFields?.adsConsent, false)
        XCTAssertEqual(preferences.sentAttributionFields?.advertisingId, "not-an-idfa")

        respond { request in
            request.json["advertising_id"] != nil
                ? Stub(status: 422, body: AttributionFixtures.errorResponse(status: 422, message: "Validation failed"))
                : Stub(status: 200, body: AttributionFixtures.attributionResponse())
        }
        await manager.sync()

        XCTAssertEqual(requests.last?.body, "{\"ads_consent\":true,\"att_status\":\"authorized\"}")
        XCTAssertEqual(preferences.sentAttributionFields?.adsConsent, true)
    }

    func testCapsTheVersionsAtTheServersLimit() async {
        respondSuccessfully()
        lookupDone()
        deviceInfo.appVersion = String(repeating: "1", count: 100)

        await manager.sync()

        XCTAssertEqual(requests.first?.json["app_version"] as? String, String(repeating: "1", count: 64))
        // Not sent again
        await manager.sync()
        XCTAssertEqual(requests.count, 1)
    }

    // MARK: - Persistence

    func testStatePersistsAcrossARestart() async {
        respondSuccessfully()
        lookupDone()
        preferences.adsConsent = true
        await manager.sync()

        // A restart: new preferences and manager on the same storage
        preferences = AppLinksPreferences(suiteName: suiteName)
        manager = makeManager()
        XCTAssertEqual(preferences.attributionId, attributionId)
        XCTAssertEqual(preferences.adsConsent, true)
        XCTAssertEqual(preferences.sentAttributionFields?.adsConsent, true)

        await manager.sync()
        XCTAssertEqual(requests.count, 1)

        preferences.adsConsent = false
        await manager.sync()
        XCTAssertEqual(requests.map(\.method), ["POST", "PATCH"])
        XCTAssertEqual(requests[1].body, "{\"ads_consent\":false}")
    }
}
