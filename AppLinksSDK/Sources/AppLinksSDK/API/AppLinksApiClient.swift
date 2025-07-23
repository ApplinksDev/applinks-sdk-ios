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
    
    init(serverUrl: String, apiKey: String?) {
        self.serverUrl = serverUrl
        self.apiKey = apiKey
        
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = readTimeout
        config.timeoutIntervalForResource = connectTimeout + readTimeout
        self.session = URLSession(configuration: config)
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
    
    // MARK: - Private Methods
    
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
