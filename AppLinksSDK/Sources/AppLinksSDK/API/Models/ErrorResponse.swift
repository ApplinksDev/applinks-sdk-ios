//
//  ErrorResponse.swift
//  AppLinksSDK
//
//  Created by Maxence Henneron on 7/18/25.
//

/// Error response model
internal struct ErrorResponse: Codable {
    let error: ErrorDetails
}

internal struct ErrorDetails: Codable {
    let status: String
    let code: Int
    let message: String
}
