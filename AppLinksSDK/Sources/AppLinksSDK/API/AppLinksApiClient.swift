import Foundation

/// API client for AppLinks server communication
internal class AppLinksApiClient {
    private let serverUrl: String
    private let apiKey: String?
    private let enableLogging: Bool
    private let session: URLSession
    
    // Timeouts
    private let connectTimeout: TimeInterval = 10.0
    private let readTimeout: TimeInterval = 10.0
    
    init(serverUrl: String, apiKey: String?, enableLogging: Bool) {
        self.serverUrl = serverUrl
        self.apiKey = apiKey
        self.enableLogging = enableLogging
        
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = readTimeout
        config.timeoutIntervalForResource = connectTimeout + readTimeout
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// Fetch link details by ID
    func fetchLink(linkId: String) async throws -> LinkResponse {
        if enableLogging {
            print("[AppLinksApiClient] Fetching link with ID: \(linkId)")
        }
        
        let url = URL(string: "\(serverUrl)/api/v1/links/\(linkId)")!
        let request = buildRequest(url: url)
        
        return try await executeRequest(request, resourceType: "link")
    }

    /// Fetch visit details by ID
    func fetchVisitDetails(visitId: String) async throws -> VisitDetailsResponse {
        if enableLogging {
            print("[AppLinksApiClient] Fetching visit details with ID: \(visitId)")
        }
        
        let url = URL(string: "\(serverUrl)/api/v1/visits/\(visitId)/details")!
        let request = buildRequest(url: url)
        
        return try await executeRequest(request, resourceType: "visit")
    }
    
    /// Retrieve link details by URL
    func retrieveLink(url linkUrl: String) async throws -> LinkRetrievalResponse {
        if enableLogging {
            print("[AppLinksApiClient] Retrieving link with URL: \(linkUrl)")
        }
        
        let url = URL(string: "\(serverUrl)/api/v1/public/links/retrieve")!
        let requestBody = LinkRetrieveRequest(url: linkUrl)
        let request = try buildPostRequest(url: url, body: requestBody)
        
        return try await executeRequest(request, resourceType: "link")
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
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
        
        if let apiKey = apiKey {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        return request
    }
    
    private func executeRequest<T: Decodable>(_ request: URLRequest, resourceType: String) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppLinksError.invalidResponse
            }
            
            if enableLogging {
                print("[AppLinksApiClient] Response code: \(httpResponse.statusCode)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
                
            case 400:
                // Try to parse error response for Bad Request
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw AppLinksError.networkError(errorResponse.error.message)
                } else {
                    throw AppLinksError.networkError("Bad request")
                }
                
            case 401:
                throw AppLinksError.networkError("Unauthorized: Invalid or missing API token")
                
            case 403:
                throw AppLinksError.networkError("Forbidden: Access denied")
                
            case 404:
                throw AppLinksError.networkError("\(resourceType.capitalized) not found")
                
            default:
                // Try to parse error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw AppLinksError.networkError(errorResponse.error.message)
                } else {
                    throw AppLinksError.networkError("Server error: \(httpResponse.statusCode)")
                }
            }
            
        } catch let error as AppLinksError {
            throw error
        } catch {
            if enableLogging {
                print("[AppLinksApiClient] Network error: \(error)")
            }
            throw AppLinksError.networkError(error.localizedDescription)
        }
    }
}
