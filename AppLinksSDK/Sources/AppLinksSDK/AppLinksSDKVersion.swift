import Foundation

/// Version information for the AppLinks SDK
public struct AppLinksSDKVersion {
    /// The current version of the SDK
    public static let current = "1.0.6"
    
    /// The name of the SDK
    public static let name = "AppLinksSDK"
    
    /// The full name with version (e.g., "AppLinksSDK/1.0.0")
    public static let fullName = "\(name)/\(current)"
    
    /// The build date of the SDK
    /// Note: This is when the SDK was built/released, not compile time
    public static let buildDate = "2025-07-23"
    
    /// User agent string for HTTP requests
    internal static var userAgent: String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        return "\(fullName) (iOS/\(osVersionString))"
    }
    
    /// Version information as a dictionary
    public static var asDictionary: [String: String] {
        return [
            "version": current,
            "name": name,
            "fullName": fullName,
            "buildDate": buildDate
        ]
    }
}