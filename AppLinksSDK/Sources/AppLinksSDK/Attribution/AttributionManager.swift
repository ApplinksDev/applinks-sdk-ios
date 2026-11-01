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

    /// Makes recording the install lookup one step
    private let lookupLock = NSLock()

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
    /// install counts, even when lookups run at the same time (the automatic
    /// one and the app's). Only the click ID is kept, nothing else of the URL.
    /// - Returns: whether this lookup was the one recorded
    @discardableResult
    nonisolated func recordInstallLookup(url: URL?) -> Bool {
        lookupLock.lock()
        guard preferences.installReportDue, !preferences.installLookupCompleted else {
            lookupLock.unlock()
            return false
        }
        preferences.pendingClickId = url.flatMap { ClickId.extract(from: $0.absoluteString) }
        preferences.installLookupCompleted = true
        lookupLock.unlock()
        trigger()
        return true
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
        if preferences.attributionId == nil {
            guard preferences.installReportDue, preferences.installLookupCompleted, !installReportDeferred,
                  await reportInstall(desired: desiredFields()) else {
                return
            }
        }
        if let attributionId = preferences.attributionId {
            await updateAttribution(id: attributionId, desired: desiredFields())
        }
    }

    /// What the server should have: the app's consent and advertising ID,
    /// and the ATT status and versions read now
    private func desiredFields() -> AttributionFields {
        let consent = preferences.consent
        return AttributionFields(
            attStatus: deviceInfo.trackingAuthorizationStatus,
            adsConsent: consent.adsConsent,
            limitedDataUse: consent.limitedDataUse,
            advertisingId: preferences.advertisingId,
            appVersion: deviceInfo.appVersion.map(Self.capped),
            osVersion: deviceInfo.osVersion.map(Self.capped)
        )
    }

    /// The server refuses a version longer than 64 characters, and with it
    /// the whole request
    private static func capped(_ version: String) -> String {
        String(version.prefix(64))
    }

    /// The fields the server always accepts, whatever the app passed
    private static let consentKeys: Set<String> = ["att_status", "ads_consent", "limited_data_use"]

    /// Report the install. Returns whether the server didn't apply all of
    /// it, which an update sends right away.
    private func reportInstall(desired: AttributionFields) async -> Bool {
        guard let bundleId = deviceInfo.bundleId, !bundleId.isEmpty else {
            logger.error("[AppLinksSDK] Install attribution: the app has no bundle ID, the install can't be reported")
            return false
        }

        var body = desired.installReportBody
        body["platform"] = "ios"
        body["bundle_id"] = bundleId
        body["click_id"] = preferences.pendingClickId

        // A report sent before without an answer may have been recorded
        let sentBefore = preferences.installReportSent
        preferences.installReportSent = true

        switch await apiClient.reportInstall(body: body) {
        case .success(let attributionId, let created):
            // The server answers a repeat (200) with the install it recorded
            // first, taking only the repeat's stricter consent. When this
            // device sent that first report, the user allowed more since, so
            // the update that follows sends it. Otherwise the install was
            // reported by another device the click ID reached (the clipboard
            // syncs across the user's Apple devices), whose choice isn't
            // overridden.
            let partlyApplied = !created && sentBefore
            preferences.sentAttributionFields = partlyApplied ? .afterRepeatedReport : desired
            preferences.attributionId = attributionId
            finishInstallReport()
            logger.info("[AppLinksSDK] Install reported: attribution \(attributionId)")
            return partlyApplied
        case .retryLater(let reason):
            installReportDeferred = true
            logger.warning("[AppLinksSDK] Install report failed (\(reason)), it will be retried at the next launch")
            return false
        case .rejected(let statusCode, let message):
            finishInstallReport()
            logger.error("[AppLinksSDK] Install attribution: \(Self.rejectionCause(statusCode: statusCode, message: message, bundleId: bundleId)) The install won't be reported.")
            return false
        }
    }

    private func finishInstallReport() {
        preferences.installReportDue = false
        preferences.installReportSent = false
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
            logger.error("[AppLinksSDK] Attribution update refused: \(Self.rejectionCause(statusCode: statusCode, message: message, bundleId: deviceInfo.bundleId))")
            let consentChanges = changes.filter { Self.consentKeys.contains($0.key) }
            if statusCode == 422, !consentChanges.isEmpty, consentChanges.count < changes.count {
                // The server refused the whole update for one of the other
                // fields (the advertising ID or a version): the consent it
                // came with is sent again without them
                await updateConsent(id: id, changes: consentChanges, desired: desired, sent: sent)
            } else {
                // Sending the same values again would be refused again
                preferences.sentAttributionFields = desired.sent(after: sent)
            }
        }
    }

    /// Send only the consent of an update refused for another field
    private func updateConsent(id: String, changes: [String: Any], desired: AttributionFields, sent: AttributionFields) async {
        // The other fields count as sent: they'd be refused again
        var withoutConsent = desired.sent(after: sent)
        withoutConsent.attStatus = sent.attStatus
        withoutConsent.adsConsent = sent.adsConsent
        withoutConsent.limitedDataUse = sent.limitedDataUse
        preferences.sentAttributionFields = withoutConsent

        switch await apiClient.updateAttribution(id: id, body: changes) {
        case .success:
            preferences.sentAttributionFields = desired.sent(after: sent)
            logger.debug("[AppLinksSDK] Attribution updated: \(changes.keys.sorted().joined(separator: ", "))")
        case .retryLater(let reason):
            logger.warning("[AppLinksSDK] Attribution update failed (\(reason)), it will be retried")
        case .rejected(let statusCode, let message):
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
