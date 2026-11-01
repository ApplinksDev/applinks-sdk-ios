import Foundation

/// The consent and device fields of an attribution: what the app wants the
/// server to have, or what the server was last sent
internal struct AttributionFields: Codable, Equatable {
    var attStatus: String?
    var adsConsent: Bool
    var limitedDataUse: Bool
    var advertisingId: String?
    var appVersion: String?
    var osVersion: String?

    /// The fields of the install report (POST), unset ones left out
    var installReportBody: [String: Any] {
        var body: [String: Any] = [
            "ads_consent": adsConsent,
            "limited_data_use": limitedDataUse
        ]
        body["att_status"] = attStatus
        body["advertising_id"] = advertisingId
        body["app_version"] = appVersion
        body["os_version"] = osVersion
        return body
    }

    /// Whether the server keeps the advertising ID with these values: it
    /// drops it unless ATT is authorized and the app's consent allows ad
    /// measurement (and removes the stored one when they stop allowing it)
    var keepsAdvertisingId: Bool {
        attStatus == "authorized" && adsConsent
    }

    /// The fields that changed since `sent` (PATCH). A removed advertising
    /// ID is sent as null; an ATT status or version that can't be read
    /// isn't sent. The advertising ID is sent again when tracking becomes
    /// allowed: the server dropped it while it wasn't.
    func changes(since sent: AttributionFields) -> [String: Any] {
        var body: [String: Any] = [:]
        if let attStatus = attStatus, attStatus != sent.attStatus {
            body["att_status"] = attStatus
        }
        if adsConsent != sent.adsConsent {
            body["ads_consent"] = adsConsent
        }
        if limitedDataUse != sent.limitedDataUse {
            body["limited_data_use"] = limitedDataUse
        }
        let nowKeepsAdvertisingId = self.sent(after: sent).keepsAdvertisingId
        if advertisingId != sent.advertisingId
            || (advertisingId != nil && nowKeepsAdvertisingId && !sent.keepsAdvertisingId) {
            body["advertising_id"] = advertisingId ?? NSNull()
        }
        if let appVersion = appVersion, appVersion != sent.appVersion {
            body["app_version"] = appVersion
        }
        if let osVersion = osVersion, osVersion != sent.osVersion {
            body["os_version"] = osVersion
        }
        return body
    }

    /// What the server has once `changes(since: sent)` was sent
    func sent(after sent: AttributionFields) -> AttributionFields {
        var fields = self
        fields.attStatus = attStatus ?? sent.attStatus
        fields.appVersion = appVersion ?? sent.appVersion
        fields.osVersion = osVersion ?? sent.osVersion
        return fields
    }
}
