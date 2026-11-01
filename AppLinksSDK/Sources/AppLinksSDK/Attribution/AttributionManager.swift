import Foundation

/// Reports the install once (POST), then keeps the server's copy of the
/// consent, ATT status, advertising ID and versions up to date (PATCH).
///
/// Every trigger runs one sync, after the syncs before it: a sync compares
/// what the app wants the server to have with what it was last sent, so
/// concurrent triggers never report the install twice, and a change made
/// while a request is in flight is sent by the sync that follows it.
internal actor AttributionManager {
    private let apiClient: AppLinksApiClient
    private let preferences: AppLinksPreferences
    private let deviceInfo: AttributionDeviceInfo
    private let logger = AppLinksSDKLogger.shared.withCategory("attribution")

    /// The last sync started, which the next one waits for
    private var lastSync: Task<Void, Never>?

    /// Set when the install report failed in a way worth retrying: it's
    /// retried at the next SDK initialisation, not by every trigger
    private var installReportDeferred = false

    init(apiClient: AppLinksApiClient, preferences: AppLinksPreferences, deviceInfo: AttributionDeviceInfo) {
        self.apiClient = apiClient
        self.preferences = preferences
        self.deviceInfo = deviceInfo
    }

    // MARK: - Triggers

    /// Sync in the background
    nonisolated func trigger() {
        Task { await self.sync() }
    }

    /// Record the result of the deferred deep link lookup the install report
    /// waits for, then report the install. Only the first lookup of a fresh
    /// install counts. Only the click ID is kept, nothing else of the URL.
    nonisolated func recordInstallLookup(url: URL?) {
        guard preferences.installReportDue, !preferences.installLookupCompleted else {
            return
        }
        preferences.pendingClickId = url.flatMap { ClickId.extract(from: $0.absoluteString) }
        preferences.installLookupCompleted = true
        trigger()
    }

    /// Sync, after the syncs already started
    func sync() async {
        let previous = lastSync
        let task = Task {
            await previous?.value
            await self.performSync()
        }
        lastSync = task
        await task.value
    }

    // MARK: - Sync

    private func performSync() async {
        let desired = desiredFields()
        if let attributionId = preferences.attributionId {
            await updateAttribution(id: attributionId, desired: desired)
        } else if preferences.installReportDue, preferences.installLookupCompleted, !installReportDeferred {
            await reportInstall(desired: desired)
        }
    }

    /// What the server should have: the app's consent and advertising ID,
    /// and the ATT status and versions read now
    private func desiredFields() -> AttributionFields {
        AttributionFields(
            attStatus: deviceInfo.trackingAuthorizationStatus,
            adsConsent: preferences.adsConsent,
            limitedDataUse: preferences.limitedDataUse,
            advertisingId: preferences.advertisingId,
            appVersion: deviceInfo.appVersion,
            osVersion: deviceInfo.osVersion
        )
    }

    private func reportInstall(desired: AttributionFields) async {
        guard let bundleId = deviceInfo.bundleId, !bundleId.isEmpty else {
            logger.error("[AppLinksSDK] Install attribution: the app has no bundle ID, the install can't be reported")
            return
        }

        var body = desired.installReportBody
        body["platform"] = "ios"
        body["bundle_id"] = bundleId
        body["click_id"] = preferences.pendingClickId

        switch await apiClient.reportInstall(body: body) {
        case .success(let attributionId):
            preferences.attributionId = attributionId
            preferences.sentAttributionFields = desired
            finishInstallReport()
            logger.info("[AppLinksSDK] Install reported: attribution \(attributionId)")
        case .retryLater(let reason):
            installReportDeferred = true
            logger.warning("[AppLinksSDK] Install report failed (\(reason)), it will be retried at the next launch")
        case .rejected(let statusCode, let message):
            finishInstallReport()
            logger.error("[AppLinksSDK] Install attribution: \(Self.rejectionCause(statusCode: statusCode, message: message, bundleId: bundleId)) The install won't be reported.")
        }
    }

    private func finishInstallReport() {
        preferences.installReportDue = false
        preferences.pendingClickId = nil
    }

    private func updateAttribution(id: String, desired: AttributionFields) async {
        let sent = preferences.sentAttributionFields ?? AttributionFields(adsConsent: false, limitedDataUse: false)
        let changes = desired.changes(since: sent)
        guard !changes.isEmpty else { return }

        switch await apiClient.updateAttribution(id: id, body: changes) {
        case .success:
            preferences.sentAttributionFields = desired.sent(after: sent)
            logger.debug("[AppLinksSDK] Attribution updated: \(changes.keys.sorted().joined(separator: ", "))")
        case .retryLater(let reason):
            logger.warning("[AppLinksSDK] Attribution update failed (\(reason)), it will be retried")
        case .rejected(let statusCode, let message):
            // Sending the same values again would be refused again
            preferences.sentAttributionFields = desired.sent(after: sent)
            logger.error("[AppLinksSDK] Attribution update refused: \(Self.rejectionCause(statusCode: statusCode, message: message, bundleId: deviceInfo.bundleId))")
        }
    }

    /// The likely cause of a refused request, for the log
    static func rejectionCause(statusCode: Int, message: String, bundleId: String?) -> String {
        switch statusCode {
        case 401:
            return "the API key was refused (401 \(message)). Pass a valid public key (pk_) to AppLinksSDK.initialize."
        case 404 where message == "App not found":
            return "no Applinks project has the iOS bundle ID \"\(bundleId ?? "")\" (404 \(message)). Set it in the project's settings."
        default:
            return "the server answered \(statusCode) (\(message))."
        }
    }
}
