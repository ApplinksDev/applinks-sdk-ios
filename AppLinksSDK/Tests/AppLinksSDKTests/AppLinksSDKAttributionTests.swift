import XCTest
import UIKit
@testable import AppLinksSDK

/// Install attribution as the SDK drives it: when the install is reported,
/// the public API, and what the app gets from the links it handles
final class AppLinksSDKAttributionTests: XCTestCase {
    private typealias Stub = MockURLProtocol.Stub

    private var host: String!
    private var suiteName: String!
    private var preferences: AppLinksPreferences!
    private var pasteboard: MockPasteboard!
    private var deviceInfo: MockAttributionDeviceInfo!
    private var notificationCenter: NotificationCenter!

    private let clickId = AttributionFixtures.clickId
    private let attributionId = AttributionFixtures.attributionId

    override func setUp() {
        super.setUp()
        host = "\(UUID().uuidString.lowercased()).applinks.test"
        suiteName = "com.applinks.sdk.tests.\(UUID().uuidString)"
        preferences = AppLinksPreferences(suiteName: suiteName)
        pasteboard = MockPasteboard()
        deviceInfo = MockAttributionDeviceInfo()
        notificationCenter = NotificationCenter()
    }

    override func tearDown() {
        preferences.clear()
        MockURLProtocol.reset(host: host)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSDK(
        apiKey: String? = "pk_test_123",
        supportedDomains: Set<String> = [],
        supportedSchemes: Set<String> = ["com.example.app"],
        deferredDeepLinkingEnabled: Bool = true,
        installAttributionEnabled: Bool = true
    ) -> AppLinksSDK {
        AppLinksSDK(
            config: AppLinksConfig(
                serverUrl: "https://\(host!)",
                apiKey: apiKey,
                supportedDomains: supportedDomains,
                supportedSchemes: supportedSchemes,
                deferredDeepLinkingEnabled: deferredDeepLinkingEnabled,
                installAttributionEnabled: installAttributionEnabled
            ),
            customMiddleware: [],
            preferences: preferences,
            clipboardManager: ClipboardManager(pasteboard: pasteboard),
            urlSession: MockURLProtocol.session(),
            attributionDeviceInfo: deviceInfo,
            notificationCenter: notificationCenter
        )
    }

    private func copy(_ string: String) {
        pasteboard.string = string
        pasteboard.hasURLs = true
    }

    private var requests: [MockURLProtocol.RecordedRequest] {
        MockURLProtocol.requests(host: host)
    }

    private var attributionRequests: [MockURLProtocol.RecordedRequest] {
        requests.filter { $0.path.hasPrefix("/api/v1/attributions") }
    }

    private func respondSuccessfully() {
        MockURLProtocol.respond(host: host) { request in
            if request.path == "/api/v1/links/retrieve" {
                return Stub(status: 200, body: AttributionFixtures.linkResponse)
            }
            return Stub(status: request.method == "POST" ? 201 : 200, body: AttributionFixtures.attributionResponse())
        }
    }

    // MARK: - Config

    func testInstallAttributionIsEnabledByDefault() {
        XCTAssertTrue(AppLinksConfig().installAttributionEnabled)
        XCTAssertFalse(AppLinksConfig(installAttributionEnabled: false).installAttributionEnabled)
    }

    // MARK: - When the install is reported

    func testReportsAFreshInstallAfterTheFirstLaunchLookup() async throws {
        respondSuccessfully()
        copy("com.example.app://products/42?ck=\(clickId)")

        let sdk = makeSDK()
        XCTAssertNil(sdk.attributionId)
        try await waitUntil { sdk.attributionId != nil }

        XCTAssertEqual(sdk.attributionId, attributionId)
        XCTAssertEqual(attributionRequests.count, 1)
        XCTAssertEqual(attributionRequests[0].method, "POST")
        XCTAssertEqual(attributionRequests[0].json["click_id"] as? String, clickId)
        XCTAssertNil(attributionRequests[0].json["url"])
        XCTAssertEqual(pasteboard.string, "")
        XCTAssertFalse(preferences.isFirstLaunch)

        // The next launch doesn't report again
        _ = makeSDK()
        try await settle()
        XCTAssertEqual(attributionRequests.count, 1)
    }

    func testReportsAnUnmatchedInstallWhenTheClipboardHasNoClickId() async throws {
        respondSuccessfully()

        let sdk = makeSDK()
        try await waitUntil { sdk.attributionId != nil }

        XCTAssertEqual(attributionRequests.count, 1)
        XCTAssertNil(attributionRequests[0].json["click_id"])
    }

    func testWaitsForTheFirstManualLookupWhenAutomaticCheckingIsOff() async throws {
        respondSuccessfully()
        copy("https://go.acme.test/promo?ck=\(clickId)")

        let sdk = makeSDK(deferredDeepLinkingEnabled: false)
        try await settle()
        XCTAssertTrue(requests.isEmpty)
        XCTAssertFalse(preferences.isFirstLaunch)
        XCTAssertTrue(preferences.installReportDue)

        // Also after a restart, until the app checks
        let restarted = makeSDK(deferredDeepLinkingEnabled: false)
        try await settle()
        XCTAssertTrue(requests.isEmpty)

        _ = await restarted.checkForDeferredDeepLink()
        try await waitUntil { restarted.attributionId != nil }
        XCTAssertEqual(attributionRequests.count, 1)
        XCTAssertEqual(attributionRequests[0].json["click_id"] as? String, clickId)

        // Later checks don't report again
        copy("https://go.acme.test/promo?ck=\(UUID().uuidString)")
        _ = await sdk.checkForDeferredDeepLink()
        try await settle()
        XCTAssertEqual(attributionRequests.count, 1)
    }

    func testAnAppUpgradedFromAnOlderSDKDoesNotReport() async throws {
        respondSuccessfully()
        preferences.markFirstLaunchCompleted()
        copy("https://go.acme.test/promo?ck=\(clickId)")

        let sdk = makeSDK(deferredDeepLinkingEnabled: false)
        _ = await sdk.checkForDeferredDeepLink()
        sdk.updateConsent(adsConsent: true)
        try await settle()

        XCTAssertTrue(attributionRequests.isEmpty)
        XCTAssertNil(sdk.attributionId)
    }

    func testDisabledInstallAttributionSendsNothing() async throws {
        respondSuccessfully()
        copy("com.example.app://products/42?ck=\(clickId)")

        let sdk = makeSDK(installAttributionEnabled: false)
        sdk.updateConsent(adsConsent: true)
        sdk.setAdvertisingId(AttributionFixtures.idfa)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        try await settle()

        XCTAssertTrue(requests.isEmpty)
        XCTAssertNil(sdk.attributionId)
        XCTAssertFalse(preferences.installReportDue)
        // Kept locally all the same
        XCTAssertTrue(preferences.adsConsent)
    }

    func testAMissingOrEmptyApiKeySendsNothing() async throws {
        respondSuccessfully()
        for apiKey in [nil, ""] as [String?] {
            preferences.clear()
            let sdk = makeSDK(apiKey: apiKey)
            sdk.updateConsent(adsConsent: true)
            try await settle()

            XCTAssertTrue(attributionRequests.isEmpty)
            XCTAssertNil(sdk.attributionId)
        }
    }

    func testAFailedReportIsRetriedAtTheNextInitialisation() async throws {
        MockURLProtocol.respond(host: host) { _ in Stub(status: 503) }
        copy("com.example.app://products/42?ck=\(clickId)")

        let sdk = makeSDK()
        try await waitUntil { self.attributionRequests.count == 1 }
        try await settle()
        XCTAssertNil(sdk.attributionId)
        XCTAssertEqual(preferences.pendingClickId, clickId)

        // Not retried before the next initialisation
        sdk.updateConsent(adsConsent: true)
        try await settle()
        XCTAssertEqual(attributionRequests.count, 1)

        // A restart, with fresh preferences on the same storage
        respondSuccessfully()
        preferences = AppLinksPreferences(suiteName: suiteName)
        let restarted = makeSDK()
        try await waitUntil { restarted.attributionId != nil }

        XCTAssertEqual(attributionRequests.count, 2)
        XCTAssertEqual(attributionRequests[1].method, "POST")
        XCTAssertEqual(attributionRequests[1].json["click_id"] as? String, clickId)
        XCTAssertEqual(attributionRequests[1].json["ads_consent"] as? Bool, true)
    }

    // MARK: - Consent

    func testConsentGivenBeforeTheReportGoesInIt() async throws {
        respondSuccessfully()
        let sdk = makeSDK(deferredDeepLinkingEnabled: false)

        sdk.updateConsent(adsConsent: true, limitedDataUse: true)
        sdk.setAdvertisingId(AttributionFixtures.idfa)
        try await settle()
        XCTAssertTrue(requests.isEmpty)

        _ = await sdk.checkForDeferredDeepLink()
        try await waitUntil { sdk.attributionId != nil }

        let body = attributionRequests[0].json
        XCTAssertEqual(body["ads_consent"] as? Bool, true)
        XCTAssertEqual(body["limited_data_use"] as? Bool, true)
        XCTAssertEqual(body["advertising_id"] as? String, AttributionFixtures.idfa)
    }

    func testConsentDefaultsToNone() async throws {
        respondSuccessfully()
        let sdk = makeSDK()
        try await waitUntil { sdk.attributionId != nil }

        let body = attributionRequests[0].body
        XCTAssertTrue(body.contains("\"ads_consent\":false"))
        XCTAssertTrue(body.contains("\"limited_data_use\":false"))
        XCTAssertFalse(body.contains("advertising_id"))
    }

    func testUpdatesAfterTheReport() async throws {
        respondSuccessfully()
        let sdk = makeSDK()
        try await waitUntil { sdk.attributionId != nil }

        sdk.updateConsent(adsConsent: true)
        try await waitUntil { self.attributionRequests.count == 2 }
        sdk.setAdvertisingId(AttributionFixtures.idfa)
        try await waitUntil { self.attributionRequests.count == 3 }
        sdk.setAdvertisingId(nil)
        try await waitUntil { self.attributionRequests.count == 4 }
        // An empty ID is none
        sdk.setAdvertisingId("")
        try await settle()

        XCTAssertEqual(attributionRequests.map(\.method), ["POST", "PATCH", "PATCH", "PATCH"])
        XCTAssertTrue(attributionRequests[1...].allSatisfy { $0.path == "/api/v1/attributions/\(self.attributionId)" })
        XCTAssertEqual(attributionRequests[1...].map(\.body), [
            "{\"ads_consent\":true}",
            "{\"advertising_id\":\"\(AttributionFixtures.idfa)\"}",
            "{\"advertising_id\":null}"
        ])
    }

    func testSetAdvertisingIdIgnoresAValueThatIsNotAnIDFA() async throws {
        respondSuccessfully()
        let sdk = makeSDK(deferredDeepLinkingEnabled: false)

        sdk.setAdvertisingId(" \(AttributionFixtures.idfa) ")
        XCTAssertEqual(preferences.advertisingId, AttributionFixtures.idfa)
        for invalid in ["Optional(\(AttributionFixtures.idfa))", "unavailable", "{\(AttributionFixtures.idfa)}", "E621E1F8C36C495A93FC0C247A3E6E5F"] {
            sdk.setAdvertisingId(invalid)
            XCTAssertEqual(preferences.advertisingId, AttributionFixtures.idfa, invalid)
        }

        // The zeroed ID iOS returns without ATT authorization is none
        sdk.setAdvertisingId("00000000-0000-0000-0000-000000000000")
        XCTAssertNil(preferences.advertisingId)

        // An invalid ID never reaches the install report
        sdk.setAdvertisingId("unavailable")
        _ = await sdk.checkForDeferredDeepLink()
        try await waitUntil { sdk.attributionId != nil }
        XCTAssertNil(attributionRequests[0].json["advertising_id"])
    }

    func testUpdateConsentRereadsTheATTStatus() async throws {
        respondSuccessfully()
        let sdk = makeSDK()
        try await waitUntil { sdk.attributionId != nil }

        deviceInfo.trackingAuthorizationStatus = "authorized"
        sdk.updateConsent(adsConsent: true)
        try await waitUntil { self.attributionRequests.count == 2 }

        XCTAssertEqual(attributionRequests[1].body, "{\"ads_consent\":true,\"att_status\":\"authorized\"}")
    }

    func testSendsTheATTStatusWhenTheAppBecomesActive() async throws {
        respondSuccessfully()
        deviceInfo.trackingAuthorizationStatus = "not_determined"
        let sdk = makeSDK()
        try await waitUntil { sdk.attributionId != nil }
        XCTAssertEqual(attributionRequests[0].json["att_status"] as? String, "not_determined")

        // Unchanged: nothing sent
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        try await settle()
        XCTAssertEqual(attributionRequests.count, 1)

        deviceInfo.trackingAuthorizationStatus = "denied"
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        try await waitUntil { self.attributionRequests.count == 2 }

        XCTAssertEqual(attributionRequests[1].method, "PATCH")
        XCTAssertEqual(attributionRequests[1].body, "{\"att_status\":\"denied\"}")
    }

    func testSendsAnAppUpdateAtInitialisation() async throws {
        respondSuccessfully()
        let sdk = makeSDK()
        try await waitUntil { sdk.attributionId != nil }

        deviceInfo.appVersion = "2.4.0"
        _ = makeSDK()
        try await waitUntil { self.attributionRequests.count == 2 }

        XCTAssertEqual(attributionRequests[1].body, "{\"app_version\":\"2.4.0\"}")
    }

    // MARK: - Links

    func testDeepLinkParamsLeaveOutTheClickId() async throws {
        respondSuccessfully()
        copy("com.example.app://products/42?ref=ad&ck=\(clickId)")
        let sdk = makeSDK(deferredDeepLinkingEnabled: false)

        let result = await sdk.checkForDeferredDeepLink()

        XCTAssertEqual(result?.handled, true)
        XCTAssertEqual(result?.path, "/products/42")
        XCTAssertEqual(result?.params, ["ref": "ad"])
    }

    func testHandledLinkParamsLeaveOutTheClickId() async {
        let sdk = makeSDK(installAttributionEnabled: false)

        let result = await sdk.getAppLinkDetails(from: URL(string: "com.example.app://products/42?ck=\(clickId.uppercased())&ref=ad")!)
        XCTAssertEqual(result.params, ["ref": "ad"])

        // A ck that isn't a click ID is the app's own
        let ownCk = await sdk.getAppLinkDetails(from: URL(string: "com.example.app://products/42?ck=summer")!)
        XCTAssertEqual(ownCk.params, ["ck": "summer"])
    }

    func testResolvesAnHttpsClipboardLinkWithoutSupportedDomains() async throws {
        respondSuccessfully()
        copy("https://go.acme.test/promo?ck=\(clickId)")
        let sdk = makeSDK(supportedSchemes: [], deferredDeepLinkingEnabled: false)

        let result = await sdk.checkForDeferredDeepLink()

        XCTAssertEqual(result?.handled, true)
        XCTAssertEqual(result?.path, "/promo/42")
        XCTAssertEqual(result?.params, ["ref": "ad"])
        let retrieve = requests.first { $0.path == "/api/v1/links/retrieve" }
        XCTAssertEqual(retrieve?.method, "POST")
        XCTAssertEqual(retrieve?.json["url"] as? String, "https://go.acme.test/promo?ck=\(clickId)")

        try await waitUntil { sdk.attributionId != nil }
        XCTAssertEqual(attributionRequests[0].json["click_id"] as? String, clickId)
    }

    func testDoesNotResolveAnHttpsClipboardLinkWithoutClickId() async throws {
        respondSuccessfully()
        copy("https://go.acme.test/promo")
        let sdk = makeSDK(supportedSchemes: [], deferredDeepLinkingEnabled: false, installAttributionEnabled: false)

        let result = await sdk.checkForDeferredDeepLink()

        XCTAssertEqual(result?.path, "")
        XCTAssertTrue(requests.isEmpty)
    }
}
