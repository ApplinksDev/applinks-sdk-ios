import Foundation

/// Request model for retrieving link details by URL
internal struct LinkRetrieveRequest: Encodable {
    let url: String
}