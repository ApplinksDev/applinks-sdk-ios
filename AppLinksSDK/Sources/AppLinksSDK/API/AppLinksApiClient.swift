import Foundation

/// API client for AppLinks server communication
internal class AppLinksApiClient {
    private let serverUrl: String
    private let apiKey: String?
    private let session: URLSession
    private let logger = AppLinksSDKLogger.shared.withCategory("api-client")
    
    // Timeouts
    private let connectTimeout: TimeInterval = 10.0
    private let readTimeout: TimeInterval = 10.0
    
    // JSON Encoder/Decoder with Rails-compatible ISO8601 date formatting
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .railsISO8601
        return encoder
    }()
    
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .railsISO8601
        return decoder
    }()
    
    /// - Parameter session: the session requests go through; tests pass one
    ///   whose requests are stubbed
    init(serverUrl: String, apiKey: String?, session: URLSession? = nil) {
        self.serverUrl = serverUrl
        self.apiKey = apiKey
        
        if let session = session {
            self.session = session
        } else {
            // Configure URLSession
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = readTimeout
            config.timeoutIntervalForResource = connectTimeout + readTimeout
            self.session = URLSession(configuration: config)
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetch link details by ID
    func fetchLink(linkId: String) async throws -> LinkResponse {
        logger.debug("[AppLinksSDK] Fetching link with ID: \(linkId)")
        
        let url = URL(string: "\(serverUrl)/api/v1/links/\(linkId)")!
        let request = buildRequest(url: url)
        
        return try await executeRequest(request, resourceType: "link")
    }
    
    /// Retrieve link details by URL
    func retrieveLink(url linkUrl: String) async throws -> LinkResponse {
        logger.debug("[AppLinksSDK] Retrieving link with URL: \(linkUrl)")
        
        let url = URL(string: "\(serverUrl)/api/v1/links/retrieve")!
        let requestBody = LinkRetrieveRequest(url: linkUrl)
        let request = try buildPostRequest(url: url, body: requestBody)
        
        return try await executeRequest(request, resourceType: "link")
    }
    
    /// Create a new link
    func createLink(domain: String, linkData: CreateLinkRequest.LinkData) async throws -> LinkResponse {
        logger.debug("[AppLinksSDK] Creating new link for domain: \(domain)")
        
        let url = URL(string: "\(serverUrl)/api/v1/links")!
        let requestBody = CreateLinkRequest(domain: domain, link: linkData)
        let request = try buildPostRequest(url: url, body: requestBody)
        
        return try await executeRequest(request, resourceType: "link")
    }
    
    /// Report the install (POST /api/v1/attributions)
    func reportInstall(body: [String: Any]) async -> AttributionApiResult {
        let url = URL(string: "\(serverUrl)/api/v1/attributions")!
        return await sendAttributionRequest(url: url, method: "POST", body: body)
    }
    
    /// Update the install's consent or versions (PATCH /api/v1/attributions/:id)
    func updateAttribution(id: String, body: [String: Any]) async -> AttributionApiResult {
        let path = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let url = URL(string: "\(serverUrl)/api/v1/attributions/\(path)")!
        return await sendAttributionRequest(url: url, method: "PATCH", body: body)
    }
    
    // MARK: - Private Methods
    
    /// The attribution bodies are built as dictionaries: a PATCH sends
    /// `"advertising_id": null` to remove the advertising ID, which
    /// JSONEncoder can't tell apart from a field left out.
    private func sendAttributionRequest(url: URL, method: String, body: [String: Any]) async -> AttributionApiResult {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(AppLinksSDKVersion.userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue(AppLinksSDKVersion.current, forHTTPHeaderField: "X-AppLinks-SDK-Version")
        if let apiKey = apiKey {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .retryLater("Invalid server response")
            }
            logger.debug("[AppLinksSDK] \(method) \(url.path) response code: \(httpResponse.statusCode)")
            
            let status = httpResponse.statusCode
            let message = (try? jsonDecoder.decode(ErrorResponse.self, from: data))?.error.message
            switch status {
            case 200, 201:
                guard let attribution = try? jsonDecoder.decode(AttributionResponse.self, from: data) else {
                    return .retryLater("Invalid server response")
                }
                return .success(attributionId: attribution.attributionId)
            case 408, 429, 500...599:
                return .retryLater(message ?? "Server error: \(status)")
            default:
                return .rejected(statusCode: status, message: message ?? "Server error: \(status)")
            }
        } catch {
            logger.debug("[AppLinksSDK] Network error: \(error)")
            return .retryLater(error.localizedDescription)
        }
    }
    
    
    private func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(AppLinksSDKVersion.userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue(AppLinksSDKVersion.current, forHTTPHeaderField: "X-AppLinks-SDK-Version")
        
        if let apiKey = apiKey {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func buildPostRequest<T: Encodable>(url: URL, body: T) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(AppLinksSDKVersion.userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue(AppLinksSDKVersion.current, forHTTPHeaderField: "X-AppLinks-SDK-Version")
        
        if let apiKey = apiKey {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try jsonEncoder.encode(body)
        
        return request
    }
    
    private func executeRequest<T: Decodable>(_ request: URLRequest, resourceType: String) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppLinksError.invalidResponse
            }
            
            logger.debug("[AppLinksSDK] Response code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200, 201:
                return try jsonDecoder.decode(T.self, from: data)
            default:
                // Try to parse error response
                if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: data) {
                    throw AppLinksError.networkError(errorResponse.error.message)
                } else {
                    throw AppLinksError.networkError("Server error: \(httpResponse.statusCode)")
                }
            }
        } catch let error as AppLinksError {
            throw error
        } catch {
            logger.debug("[AppLinksSDK] Network error: \(error)")
            throw AppLinksError.networkError(error.localizedDescription)
        }
    }
}
