import Foundation

/// The click ID ("ck") a link page hands the app, a UUID
internal enum ClickId {
    /// The ck parameter of a URL, found without parsing the URL, like the
    /// server's CK_PARAM: the URL can hold spaces or accented letters that a
    /// strict URL parser refuses, or a #fragment after the ck parameter.
    private static let ckParam = try! NSRegularExpression(
        pattern: "[?&]ck=([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})(?=[&#]|\\z)"
    )

    private static let uuid = try! NSRegularExpression(
        pattern: "\\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\z"
    )

    /// The click ID in the URL's ck parameter, lowercased, or nil
    static func extract(from url: String) -> String? {
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(url.startIndex..., in: url)
        guard let match = ckParam.firstMatch(in: url, range: range),
              let idRange = Range(match.range(at: 1), in: url) else {
            return nil
        }
        return url[idRange].lowercased()
    }

    /// Whether the value is a UUID
    static func isClickId(_ value: String) -> Bool {
        uuid.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    /// The deep link params without the ck parameter the link page added
    static func removingClickId(from params: [String: String]) -> [String: String] {
        guard let value = params["ck"], isClickId(value) else {
            return params
        }
        var params = params
        params.removeValue(forKey: "ck")
        return params
    }
}
