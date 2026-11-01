import Foundation
import XCTest
@testable import AppLinksSDK

// MARK: - Stubbed network

/// Answers the requests of a session with stubs, per host, and records them.
/// Each test uses its own host, so a request still running from another
/// test never reaches it.
final class MockURLProtocol: URLProtocol {
    struct Stub {
        var status: Int = 200
        var body: String = ""
        var error: URLError? = nil
        var delay: TimeInterval = 0
    }

    struct RecordedRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: String

        var json: [String: Any] {
            (try? JSONSerialization.jsonObject(with: Data(body.utf8))) as? [String: Any] ?? [:]
        }
    }

    private static let lock = NSLock()
    private static var responders: [String: (RecordedRequest) -> Stub] = [:]
    private static var recorded: [String: [RecordedRequest]] = [:]

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func respond(host: String, _ responder: @escaping (RecordedRequest) -> Stub) {
        locked { responders[host] = responder }
    }

    static func requests(host: String) -> [RecordedRequest] {
        locked { recorded[host] ?? [] }
    }

    static func reset(host: String) {
        locked {
            responders[host] = nil
            recorded[host] = nil
        }
    }

    private static func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host ?? ""
        let recordedRequest = RecordedRequest(
            method: request.httpMethod ?? "GET",
            path: request.url?.path ?? "",
            headers: request.allHTTPHeaderFields ?? [:],
            body: String(decoding: Self.body(of: request), as: UTF8.self)
        )
        let responder = Self.locked { () -> ((RecordedRequest) -> Stub)? in
            Self.recorded[host, default: []].append(recordedRequest)
            return Self.responders[host]
        }
        let stub = responder?(recordedRequest) ?? Stub(status: 500)

        DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay) { [self] in
            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    /// URLSession hands the body to the protocol as a stream
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

// MARK: - Device

final class MockAttributionDeviceInfo: AttributionDeviceInfo, @unchecked Sendable {
    var bundleId: String? = "com.example.app"
    var appVersion: String? = "2.3.1"
    var osVersion: String? = "17.5.1"
    var trackingAuthorizationStatus: String? = "not_determined"
}

// MARK: - Helpers

enum AttributionFixtures {
    static let clickId = "9b2e4c1a-7f3d-4e8b-a2c6-5d1f0e9b8a7c"
    static let attributionId = "c41f5e2a-9d8b-4c7e-b6a1-3f2e1d0c9b8a"
    static let idfa = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"

    static func attributionResponse(id: String = attributionId, matched: Bool = false) -> String {
        "{\"attribution_id\":\"\(id)\",\"matched\":\(matched),\"link\":null}"
    }

    static func errorResponse(status: Int, message: String) -> String {
        "{\"error\":{\"status\":\"error\",\"code\":\(status),\"message\":\"\(message)\"}}"
    }

    static let linkResponse = """
    {"id":"3d6f0a1e-0000-0000-0000-000000000000","title":"Black Friday","alias_path":"promo",\
    "domain":"go.acme.test","original_url":"https://acme.com/black-friday","deep_link_path":"/promo/42",\
    "deep_link_params":{"ref":"ad"},"expires_at":null,"template_id":null,\
    "created_at":"2026-10-01T00:00:00Z","updated_at":"2026-10-01T00:00:00Z","full_url":"https://go.acme.test/promo"}
    """
}

extension XCTestCase {
    /// Waits until the condition holds, failing after the timeout
    func waitUntil(
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for the condition", file: file, line: line)
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Lets background work run, to check it did nothing
    func settle() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}
