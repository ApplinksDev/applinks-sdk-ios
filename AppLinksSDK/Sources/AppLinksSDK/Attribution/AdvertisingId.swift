import Foundation

/// The advertising ID (IDFA) an app passes to setAdvertisingId
internal enum AdvertisingId {
    enum Value: Equatable {
        /// No ID: nil, empty, or the zeroed ID iOS returns without ATT authorization
        case none
        case id(String)
        /// Not an IDFA. The server would refuse the whole request it's in.
        case invalid
    }

    static let zeroed = "00000000-0000-0000-0000-000000000000"

    static func parse(_ value: String?) -> Value {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty, value != zeroed else {
            return .none
        }
        return ClickId.isClickId(value) ? .id(value) : .invalid
    }
}
