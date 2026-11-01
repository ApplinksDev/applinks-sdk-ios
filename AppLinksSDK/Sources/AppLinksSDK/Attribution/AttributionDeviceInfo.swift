import Foundation
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// What the install report says about the app and the device. Injected so
/// tests can control it.
internal protocol AttributionDeviceInfo {
    /// The app's bundle ID
    var bundleId: String? { get }
    /// The app's version, for example "2.3.1"
    var appVersion: String? { get }
    /// The iOS version, for example "17.5.1"
    var osVersion: String? { get }
    /// The App Tracking Transparency status: "authorized", "denied",
    /// "restricted" or "not_determined"
    var trackingAuthorizationStatus: String? { get }
}

/// The real app and device
internal struct SystemAttributionDeviceInfo: AttributionDeviceInfo {
    var bundleId: String? {
        Bundle.main.bundleIdentifier
    }

    var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var osVersion: String? {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        var string = "\(version.majorVersion).\(version.minorVersion)"
        if version.patchVersion > 0 {
            string += ".\(version.patchVersion)"
        }
        return string
    }

    /// Reads the status, never requests authorization (that's the app's call)
    var trackingAuthorizationStatus: String? {
        #if canImport(AppTrackingTransparency)
        return Self.attStatus(ATTrackingManager.trackingAuthorizationStatus)
        #else
        return nil
        #endif
    }

    #if canImport(AppTrackingTransparency)
    /// The server's name for an ATT status
    static func attStatus(_ status: ATTrackingManager.AuthorizationStatus) -> String? {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "not_determined"
        @unknown default: return nil
        }
    }
    #endif
}
