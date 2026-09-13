import XCTest
@testable import Overlap

private final class MockRecipeProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        if path == "/offline" {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let status = path == "/rate" ? 429 : 200
        let payload = path == "/legacy" ? "{\"name\":\"Volcano\",\"emoji\":\"🌋\"}" : "{\"name\":\"Nether\",\"emoji\":\"🔥\",\"contextKey\":\"v1:minecraft\",\"promptVersion\":\"context-v1\"}"
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(payload.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ClientTests: XCTestCase {
    private func client(_ path: String) -> ComboFallbackClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockRecipeProtocol.self]
        return ComboFallbackClient(endpoint: URL(string: "https://example.test/\(path)"), session: URLSession(configuration: config))
    }
    func testLegacyServiceCannotContaminateCustomContext() async throws {
        let none = try await client("legacy").combine(left: "Fire", right: "Fire")
        XCTAssertEqual(none.name, "Volcano")
        do {
            _ = try await client("legacy").combine(left: "Fire", right: "Fire", context: CraftContext(text: "Minecraft"))
            XCTFail("Custom contexts require matching context metadata")
        } catch { XCTAssertEqual(error as? ComboFallbackClient.Failure, .invalidResponse) }
        let themed = try await client("context").combine(left: "Fire", right: "Fire", context: CraftContext(text: "Minecraft"))
        XCTAssertEqual(themed.name, "Nether")
    }
    func testTypedErrors() async {
        for (path, expected) in [("rate", ComboFallbackClient.Failure.rateLimited), ("offline", .offline)] {
            do {
                _ = try await client(path).combine(left: "Fire", right: "Fire")
                XCTFail("Expected error")
            } catch { XCTAssertEqual(error as? ComboFallbackClient.Failure, expected) }
        }
    }
}
